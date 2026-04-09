import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/models/user.dart';
import 'package:skycase/providers/auto_flight_provider.dart';
import 'package:skycase/providers/auto_simlink_provider.dart';
import 'package:skycase/providers/deep_zoom_provider.dart';
import 'package:skycase/providers/efb_ui_mode_provider.dart';
import 'package:skycase/providers/home_arrival_provider.dart';
import 'package:skycase/providers/navigraph_provider.dart';
import 'package:skycase/providers/route_builder_provider.dart';
import 'package:skycase/providers/simbrief_provider.dart';

import 'package:skycase/providers/state_persistence_provider.dart';
import 'package:skycase/providers/unit_system_provider.dart';
import 'package:skycase/providers/theme_provider.dart';
import 'package:skycase/providers/user_provider.dart';
import 'package:skycase/screens/home_controller_screen.dart';
import 'package:skycase/screens/auth_screen.dart';
import 'package:skycase/services/distance_tracker.dart';
import 'package:skycase/services/flight_log_service.dart';

import 'package:skycase/services/simlink_socket_service.dart';
import 'package:skycase/services/user_service.dart';
import 'package:skycase/theme/themes.dart';
import 'package:skycase/utils/session_manager.dart';

// ✅ Global SimLink singleton
final SimLinkSocketService simLinkService = SimLinkSocketService();


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

 
  await DistanceTracker.init();
  final token = await SessionManager.loadToken();
  User? user;

  if (token != null && JwtDecoder.isExpired(token)) {
    print('[MAIN] ⛔ Token is expired. Clearing...');
    await SessionManager.clearToken();
  } else if (token != null) {
    try {
      final userService = UserService(baseUrl: 'http://38.242.241.46:3000');
      final fullProfile = await userService.getProfile(token);
      user = fullProfile.copyWith(token: token);

      // ⭐ UNIVERSAL LAST-DESTINATION FIX
      if (fullProfile.hq?.icao != null) {
        await initializeLastDestination(fullProfile.id, fullProfile.hq!.icao);
      } else {
        print("⚠️ [INIT] User has no HQ ICAO — skipping last destination init");
      }
    } catch (e, stack) {
      print('[MAIN] Stack trace:\n$stack');
      await SessionManager.clearToken();
      user = null;
    }
  }

  runApp(SkyCaseFS(initialUser: user));
}

Future<void> initializeLastDestination(String userId, String hqIcao) async {
  final prefs = await SharedPreferences.getInstance();

  // Fetch flight logs from backend
  final logs = await FlightLogService.getFlightLogs(userId);

  if (logs.isNotEmpty && logs.first.endLocation?.icao != null) {
    final lastIcao = logs.first.endLocation!.icao.toUpperCase();
    await prefs.setString("last_destination_icao", lastIcao);
    print("🛬 [INIT] Using last flight destination → $lastIcao");
    return;
  }

  // No flights → use HQ
  await prefs.setString("last_destination_icao", hqIcao.toUpperCase());
  print("🏠 [INIT] Using HQ ICAO → $hqIcao");
}

// 🧹 Optional debug wipe
void clearPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  print('[DEBUG] ✅ All SharedPreferences cleared');
}

class SkyCaseFS extends StatelessWidget {
  final User? initialUser;
  const SkyCaseFS({super.key, required this.initialUser});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ChangeNotifierProvider(create: (_) => UserProvider()),
    ChangeNotifierProvider(create: (_) => UnitSystemProvider()),
    ChangeNotifierProvider(create: (_) => StatePersistenceProvider()),
    ChangeNotifierProvider(create: (_) => AutoFlightProvider()),
    ChangeNotifierProvider(create: (_) => AutoSimLinkProvider()),
    ChangeNotifierProvider(create: (_) => NavigraphProvider()),
    ChangeNotifierProvider(create: (_) => RouteBuilderProvider()),
    ChangeNotifierProvider(create: (_) => EfbUiModeProvider()),
    ChangeNotifierProvider(create: (_) => HomeArrivalProvider()),
    ChangeNotifierProvider(create: (_) => SimBriefProvider()..load()),
    ChangeNotifierProvider(create: (_) => DeepZoomProvider()),

    StreamProvider<SimLinkData?>.value(
      value: SimLinkSocketService().stream,
      initialData: null,
    ),
  ],
      child: Builder(
        builder: (context) {
          // 🔑 Set user if available
          if (initialUser != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<UserProvider>().setUser(initialUser!);
            });
          }

          final themeProvider = context.watch<ThemeProvider>();
          final user = context.watch<UserProvider>().user;

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'SkyCaseFS',
            theme: lightTheme,
            darkTheme: navigraphDarkTheme,
            themeMode: themeProvider.themeMode,
            home: user == null ? const AuthScreen() : const HomeControllerScreen(),
          );
        },
      ),
    );
  }
}
