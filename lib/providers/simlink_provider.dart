import 'package:flutter/material.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/services/simlink_socket_service.dart';

class SimLinkProvider extends ChangeNotifier {
  SimLinkData? data;

  SimLinkProvider() {
    // Listen to incoming SimLink stream
    SimLinkSocketService().stream.listen((d) {
      data = d;
      notifyListeners();
    });
  }
}
