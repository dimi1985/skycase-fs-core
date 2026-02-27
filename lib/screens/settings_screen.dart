import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skycase/models/user.dart';
import 'package:skycase/providers/auto_flight_provider.dart';
import 'package:skycase/providers/auto_simlink_provider.dart';
import 'package:skycase/providers/efb_ui_mode_provider.dart';
import 'package:skycase/providers/navigraph_provider.dart';
import 'package:skycase/providers/theme_provider.dart';
import 'package:skycase/providers/unit_system_provider.dart';
import 'package:skycase/providers/user_provider.dart';
import 'package:skycase/services/user_service.dart';
import 'package:skycase/utils/airport_repository.dart';
import 'package:skycase/utils/session_manager.dart';
import 'package:skycase/screens/auth_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final themeProvider = context.watch<ThemeProvider>();
    final isDark = theme.brightness == Brightness.dark;

    final unitProvider = context.watch<UnitSystemProvider>();
    final autoFlightProvider = context.watch<AutoFlightProvider>();
    final autoSimLinkProvider = context.watch<AutoSimLinkProvider>();
    final navProvider = context.watch<NavigraphProvider>();
    final efbModeProvider = context.watch<EfbUiModeProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colors.onBackground,
      ),

      backgroundColor: colors.background,

      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ================================================
          // USER BLOCK
          // ================================================
          Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: colors.surfaceVariant,
                child: const Icon(Icons.person, size: 35),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.username ?? 'Unknown User',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.onBackground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'Unknown email',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 40),
          Text(
            "Preferences",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onBackground,
            ),
          ),
          const SizedBox(height: 16),

          // ================================================
          // THEME TOGGLE
          // ================================================
          SwitchListTile(
            title: const Text('Dark Theme'),
            subtitle: Text(
              isDark ? "Navigraph Mode Active" : "SkyCase Light Mode",
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            value: themeProvider.themeMode == ThemeMode.dark,
            activeColor: colors.primary,
            onChanged: (value) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                themeProvider.toggleTheme(value);
              });
            },
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: colors.primary,
            ),
          ),

          const SizedBox(height: 8),

          // ================================================
          // UNIT SYSTEM
          // ================================================
          SwitchListTile(
            title: const Text('Use Metric Units'),
            subtitle: Text(
              "Switch between KG/NM and LBS/MI",
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            value: unitProvider.isMetric,
            activeColor: colors.primary,
            onChanged: (value) => unitProvider.toggleUnitSystem(),
            secondary: Icon(
              unitProvider.isMetric ? Icons.straighten : Icons.scale,
              color: colors.primary,
            ),
          ),

          const SizedBox(height: 8),

          // ================================================
          // NAVIGRAPH TOGGLE
          // ================================================
          SwitchListTile(
            title: const Text("Navigraph Premium"),
            subtitle: Text(
              "Enable charts overlay & quick access",
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            value: navProvider.hasPremium,
            activeColor: colors.primary,
            onChanged: (value) {
              navProvider.setPremium(value);
            },
            secondary: const Icon(Icons.map),
          ),

          const SizedBox(height: 40),
          SwitchListTile(
            title: const Text('Auto Flight Detection'),
            subtitle: Text(
              "Automatically start/stop flights like Volanta",
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            value: autoFlightProvider.autoFlight,
            activeColor: colors.primary,
            onChanged: (value) => autoFlightProvider.setAutoFlight(value),
            secondary: Icon(Icons.flight_takeoff, color: colors.primary),
          ),

          const SizedBox(height: 40),
          SwitchListTile(
            title: const Text('Auto Connect to SimLink'),
            subtitle: Text(
              "Reconnect automatically when SkyCase starts",
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            value: autoSimLinkProvider.autoConnect,
            activeColor: colors.primary,
            onChanged: (value) => autoSimLinkProvider.setAutoConnect(value),
            secondary: Icon(Icons.link, color: colors.primary),
          ),

          const SizedBox(height: 40),

          Text(
            "Operations",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onBackground,
            ),
          ),

          const SizedBox(height: 16),

          SwitchListTile(
            title: const Text("Advanced EFB UI"),
            subtitle: Text(
              efbModeProvider.isCinematic
                  ? "Cinematic post-flight experience"
                  : "Minimal operational layout",
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            value: efbModeProvider.isCinematic,
            onChanged: (value) {
              efbModeProvider.setMode(
                value ? EfbUiMode.cinematic : EfbUiMode.minimal,
              );
            },
            secondary: Icon(Icons.tablet_mac, color: colors.primary),
          ),

          const SizedBox(height: 40),

          ListTile(
            leading: Icon(Icons.home_work_outlined, color: colors.primary),
            title: const Text("Change HQ"),
            subtitle: Text(
              user?.hq?.icao != null
                  ? "Current HQ: ${user!.hq!.icao}"
                  : "No HQ set",
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final controller = TextEditingController(
                text: user?.hq?.icao ?? "",
              );

              final changed = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("Change HQ"),
                    content: TextField(
                      controller: controller,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 4,
                      decoration: const InputDecoration(
                        hintText: "Enter ICAO (e.g. LGAV)",
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text("Cancel"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final icao = controller.text.trim().toUpperCase();
                          if (icao.length != 4) return;

                          final token = await SessionManager.loadToken();
                          if (token == null) return;

                          final repo = AirportRepository();
                          await repo.load();

                          final airport = repo.find(icao);
                          if (airport == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Airport ICAO not found"),
                              ),
                            );
                            return;
                          }

                          final success = await UserService(
                            baseUrl: "http://38.242.241.46:3000",
                          ).updateHq(
                            HqLocation(
                              icao: airport.icao,
                              lat: airport.lat,
                              lon: airport.lon,
                            ),
                            token,
                          );

                          if (success && context.mounted) {
                            Navigator.pop(context, true);
                          }
                        },
                        child: const Text("Save"),
                      ),
                    ],
                  );
                },
              );

              if (changed == true && context.mounted) {
                await context.read<UserProvider>().refreshProfile();
              }
            },
          ),

          const SizedBox(height: 40),
          Text(
            "Account",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.onBackground,
            ),
          ),
          const SizedBox(height: 16),

          // ================================================
          // LOGOUT BUTTON
          // ================================================
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await SessionManager.clearToken();
              context.read<UserProvider>().clearUser();

              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
