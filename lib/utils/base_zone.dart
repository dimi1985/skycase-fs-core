import 'package:latlong2/latlong.dart';

abstract class BaseZone {
  String get name;
  LatLng get center;
  double get radiusNm;
}
