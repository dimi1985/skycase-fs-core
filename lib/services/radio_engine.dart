import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:mp_audio_stream/mp_audio_stream.dart';

class RadioEngine {
  // ============================================================
  // 🔥 Singleton
  // ============================================================
  RadioEngine._internal();
  static final RadioEngine instance = RadioEngine._internal();

  // ============================================================
  // 🔧 Hardware + DSP
  // ============================================================
  final AudioRecorder _recorder = AudioRecorder();
  final audioStream = getAudioStream();

  StreamSubscription<Uint8List>? _micSub;

  // ============================================================
  // 📡 Radio state
  // ============================================================
  bool batteryOn = false;
  bool avionicsOn = false;
  bool com1On = false;

  bool pttActive = false;
  bool icsEnabled = true; // HOT-MIC
  double sidetoneVolume = 0.7;

  // ============================================================
  // 🎚 DSP filter states (radio)
  // ============================================================
  double _hpA = 0, _lpA = 0;
  double _hpLastX = 0, _hpLastY = 0, _lpLastY = 0;

  // ============================================================
  // 🎧 Noise + random
  // ============================================================
  final _rng = math.Random();

  // ============================================================
  // 🔊 Squelch + Noise
  // ============================================================
  final _player = AudioPlayer(); // for RX tail mp3
  Timer? _hissTimer;

  void _pushNoise({required int ms, required double amp}) {
    final sr = 44100;
    final frames = sr * ms ~/ 1000;
    final buf = Float32List(frames * 2);

    for (int i = 0; i < frames; i++) {
      final n =
          ((_rng.nextDouble() * 2 - 1) + (_rng.nextDouble() * 2 - 1)) * 0.5;

      final s = (n * amp).clamp(-1.0, 1.0);

      buf[i * 2] = s;
      buf[i * 2 + 1] = s;
    }

    audioStream.push(buf);
  }

  void _playTxSquelch() => _pushNoise(ms: 40, amp: 0.25);

  void _playRxSquelch() {
    _player.play(AssetSource('audio/rx_squelch.mp3'));
    _pushNoise(ms: 120, amp: 0.20);
  }

  // ============================================================
  // 🚀 INIT
  // ============================================================
  Future<void> init() async {
    // Init output audio
    try {
      audioStream.uninit();
    } catch (_) {}
    audioStream.init(
      channels: 2,
      sampleRate: 44100,
      bufferMilliSec: 50,
      waitingBufferMilliSec: 10,
    );

    // Init microphone
    if (!await _recorder.hasPermission()) return;
    final stream = await _recorder.startStream(
      const RecordConfig(
        sampleRate: 44100,
        numChannels: 1,
        encoder: AudioEncoder.pcm16bits,
      ),
    );

    _computeRadioFilter(44100, 300.0, 3000.0);

    _micSub = stream.listen(_processMicFrame);

    startHiss(); // add this
  }

  // ============================================================
  // 🔌 SHUTDOWN
  // ============================================================
Future<void> dispose() async {
  _hissTimer?.cancel();     // <-- add this
  await _micSub?.cancel();
  await _recorder.stop();
  audioStream.uninit();
}

  // ============================================================
  // 🔧 UPDATE FROM SIMLINK
  // ============================================================
 void updateAircraftState({
  required bool battery,
  required bool avionics,
  required bool com1,
}) {
  batteryOn = battery;
  avionicsOn = avionics;
  com1On = com1;

  if (!batteryOn) {
    // reset DSP internal states
    _hpLastX = 0;
    _hpLastY = 0;
    _lpLastY = 0;
  }
}

  // ============================================================
  // 🔧 PTT (called from UI / Gamepad)
  // ============================================================
  void setPTT(bool active) {
    if (active && pttActive) return;
    if (!active && !pttActive) return;

    if (active) {
      if (batteryOn && avionicsOn && com1On) {
        pttActive = true;
        _playTxSquelch();
      }
    } else {
      pttActive = false;
      _playRxSquelch();
    }
  }

  void startHiss() {
    _hissTimer?.cancel();
    _hissTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      // Only hiss if electricals are alive
      if (!batteryOn) return;

      // No hiss during PTT silence if squelch is active
      if (!icsEnabled && !pttActive) return;

      final hiss = Float32List(2205 * 2);
      for (int i = 0; i < 2205; i++) {
        final n =
            ((_rng.nextDouble() * 2 - 1) + (_rng.nextDouble() * 2 - 1)) * 0.5;
        final s = (n * 0.017).clamp(-1.0, 1.0);
        hiss[i * 2] = s;
        hiss[i * 2 + 1] = s;
      }

      audioStream.push(hiss);
    });
  }

  // ============================================================
  // 🎚 RADIO DSP FILTER
  // ============================================================
  void _computeRadioFilter(int sr, double hpCut, double lpCut) {
    final dt = 1.0 / sr;
    final rcHP = 1.0 / (2 * math.pi * hpCut);
    final rcLP = 1.0 / (2 * math.pi * lpCut);

    _hpA = rcHP / (rcHP + dt);
    _lpA = dt / (rcLP + dt);
  }

  // ============================================================
  // 🎙 UNIFIED MIC ENGINE
  // ============================================================
  void _processMicFrame(Uint8List data) {
    if (!batteryOn) return; // aircraft dead → nothing

    final bd = ByteData.sublistView(data);
    final samples = data.length ~/ 2;

    final icsOut = Float32List(samples * 2);
    final radioOut = Float32List(samples * 2);

    for (int i = 0; i < samples; i++) {
      final raw16 = bd.getInt16(i * 2, Endian.little);
      double x = raw16 / 32768.0;

      // ============================================================
      // 🎧 ICS HOT-MIC (cockpit sidetone)
      // Only if:
      // - battery on
      // - ICS enabled
      // - NOT transmitting radio
      // ============================================================
      if (icsEnabled && !pttActive) {
        double y = x;

        // warm cockpit vibe
        y *= 1.4;

        // subtle danger edge
        y = y - (y * y * y) * 0.22;

        // random presence
        y += (_rng.nextDouble() * 0.004) - 0.002;

        // soft compressor
        final a = y.abs();
        if (a > 0.75) {
          y = (0.75 + (a - 0.75) * 0.25) * y.sign;
        }

        y *= sidetoneVolume;
        y = y.clamp(-1.0, 1.0);

        icsOut[i * 2] = y;
        icsOut[i * 2 + 1] = y;
      }

      // ============================================================
      // 🎤 RADIO CHAIN (PTT)
      // Only if:
      // - PTT ON
      // - battery + avionics + com1 all ON
      // ============================================================
      if (pttActive && batteryOn && avionicsOn && com1On) {
        final yhp = _hpA * (_hpLastY + x - _hpLastX);
        _hpLastX = x;
        _hpLastY = yhp;

        _lpLastY = _lpLastY + _lpA * (yhp - _lpLastY);
        double y = _lpLastY;

        // crunch
        y = (math.tan(1.4 * y)) * 0.8;
        y = (y * 48).round() / 48.0;
        y += (_rng.nextDouble() * 2 - 1) * 0.003;

        y = y.clamp(-1.0, 1.0);

        radioOut[i * 2] = y;
        radioOut[i * 2 + 1] = y;
      }
    }

    if (icsEnabled && !pttActive) {
      audioStream.push(icsOut);
    }

    if (pttActive && batteryOn && avionicsOn && com1On) {
      audioStream.push(radioOut);
    }
  }
}
