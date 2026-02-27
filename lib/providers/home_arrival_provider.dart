import 'package:flutter/material.dart';

class HomeArrivalProvider extends ChangeNotifier {
  String? _icao;
  String? _parking;

  String? get icao => _icao;
  String? get parking => _parking;

  void setArrival({required String icao, String? parking}) {
    _icao = icao;
    _parking = parking;
    notifyListeners();
  }
}
