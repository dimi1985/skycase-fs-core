import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/utils/session_manager.dart';
import 'package:skycase/utils/aircraft_tracker.dart';

class SimLinkSocketService {
  // ---------------------------------------------------------------------------
  // SINGLETON
  // ---------------------------------------------------------------------------
  static final SimLinkSocketService _instance =
      SimLinkSocketService._internal();
  factory SimLinkSocketService() => _instance;
  SimLinkSocketService._internal();

  // ---------------------------------------------------------------------------
  // STATE
  // ---------------------------------------------------------------------------
  IOWebSocketChannel? _channel;
  StreamSubscription? _subscription;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _manualMode = false;

  SimLinkData? _latestData;
  SimLinkData? get latestData => _latestData;

  final StreamController<SimLinkData> _controller =
      StreamController<SimLinkData>.broadcast();
  Stream<SimLinkData> get stream => _controller.stream;

  // ---------------------------------------------------------------------------
  // INTERNAL: FORCE CLOSE
  // ---------------------------------------------------------------------------
  Future<void> _forceClose() async {
    try {
      await _subscription?.cancel();
      await _channel?.sink.close();
    } catch (_) {}

    _subscription = null;
    _channel = null;
    _isConnected = false;
    _isConnecting = false;
  }

  // ---------------------------------------------------------------------------
  // CONNECT (SAFE ON DESKTOP / WEB)
  // ---------------------------------------------------------------------------
  Future<void> connect(Function(SimLinkData) onData) async {
    if (_isConnected || _isConnecting) {
      print('⚠️ [SimLink] connect ignored (already active)');
      return;
    }

    _isConnecting = true;
    await _forceClose();

    final token = await SessionManager.loadToken();
    final uri =
        Uri.parse('ws://38.242.241.46:3000/simlink?token=$token');

    print('🔌 [SimLink] Connecting → $uri');

    try {
      _channel = IOWebSocketChannel.connect(uri);

      _subscription = _channel!.stream.listen(
        _handleRawFrame(onData),
        onDone: () async {
          print('🔴 [SimLink] disconnected');
          await _forceClose();
        },
        onError: (e) async {
          print('❌ [SimLink] socket error: $e');
          await _forceClose();
        },
        cancelOnError: true,
      );

      _isConnected = true;
      print('🟢 [SimLink] Connected');
    } catch (e) {
      print('💥 [SimLink] connect failed: $e');
      await _forceClose();
    } finally {
      _isConnecting = false;
    }
  }

  // ---------------------------------------------------------------------------
  // RAW FRAME HANDLER (THE IMPORTANT PART)
  // ---------------------------------------------------------------------------
  void Function(dynamic) _handleRawFrame(
    Function(SimLinkData) onData,
  ) {
    return (raw) {
      if (raw == null) return;

      final text = raw.toString().trim();

      // 🛑 HARD GUARDS — REQUIRED FOR DESKTOP / WEB
      if (text.isEmpty) return;
      if (!text.startsWith('{') && !text.startsWith('[')) {
        print('⚠️ [SimLink] Ignored non-JSON frame');
        return;
      }

      try {
        final decoded = jsonDecode(text);

        if (decoded is! Map<String, dynamic>) {
          print('⚠️ [SimLink] Ignored invalid JSON payload');
          return;
        }

        final data = SimLinkData.fromJson(decoded);

        _latestData = data;
        onData(data);

        if (!_controller.isClosed) {
          _controller.add(data);
        }

        AircraftTracker.updateFromTelemetry(data);
      } catch (e) {
        print('❌ [SimLink] JSON parse failed: $e');
      }
    };
  }

  // ---------------------------------------------------------------------------
  // RESET (NON-BREAKING)
  // ---------------------------------------------------------------------------
  Future<void> reset(
    Function(SimLinkData) onUpdate, {
    bool manual = false,
  }) async {
    _manualMode = manual;

    if (_isConnected) {
      print('⚠️ [SimLink] reset ignored → socket alive');
      return;
    }

    await connect(onUpdate);
  }

  // ---------------------------------------------------------------------------
  // SEND RAW MESSAGE
  // ---------------------------------------------------------------------------
  void sendRaw(String raw) {
    if (_channel == null) return;
    _channel!.sink.add(raw);
  }

  // ---------------------------------------------------------------------------
  // DISPOSE
  // ---------------------------------------------------------------------------
  Future<void> dispose() async => _forceClose();
}

