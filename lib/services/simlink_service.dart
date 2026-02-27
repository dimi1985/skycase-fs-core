import 'package:skycase/services/simlink_socket_service.dart';
import 'package:skycase/models/simlink_data.dart';

class SimLinkService {
  static SimLinkSocketService get _s => SimLinkSocketService();

  /// Latest telemetry data from SimLink
  static SimLinkData? get latest => _s.latestData;

  /// Live stream of telemetry events
  static Stream<SimLinkData> get stream => _s.stream;



  /// Connect wrapper
  static Future<void> connect(Function(SimLinkData) onData) {
    return _s.connect(onData);
  }

  /// Force reset the socket (optional)
  static Future<void> reset(Function(SimLinkData) onData) {
    return _s.reset(onData);
  }
}
