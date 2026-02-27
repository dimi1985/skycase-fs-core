import 'package:flutter/material.dart';
import 'package:skycase/models/user.dart';
import 'package:skycase/services/user_service.dart';
import 'package:skycase/utils/session_manager.dart';

class UserProvider extends ChangeNotifier {
  User? user;

  void setUser(User newUser) {
    user = newUser;
    notifyListeners();
  }

  void clearUser() {
    user = null;
    notifyListeners();
  }

  /// 🔄 Refresh user profile from backend
  Future<void> refreshProfile() async {
    final token = await SessionManager.loadToken();
    if (token == null) return;

    try {
      final service = UserService(
        baseUrl: "http://38.242.241.46:3000",
      );

      final updatedUser = await service.getProfile(token);
      user = updatedUser;
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Failed to refresh profile: $e");
    }
  }
}
