import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:skycase/providers/home_arrival_provider.dart';
import 'package:skycase/providers/user_provider.dart';
import 'package:skycase/widgets/home_airport_surface_map.dart';

class HomeAdvancedScreen extends StatelessWidget {
  const HomeAdvancedScreen({super.key});

  String _utcTime() => DateFormat("HH:mm").format(DateTime.now().toUtc());
  String _utcDate() => DateFormat("dd MMM yyyy").format(DateTime.now().toUtc());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = context.watch<UserProvider>().user;
    const heroImages = [
      "assets/images/home_backgrounds/bg1.png",
      "assets/images/home_backgrounds/bg2.png",
    ];
    final minute = DateTime.now().minute;
    final heroImage = heroImages[(minute ~/ 30) % heroImages.length];

    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;

          // ✅ Responsive hero height
          // mobile portrait: smaller
          // desktop: bigger
          final heroHeight = (h * (w < 520 ? 0.34 : 0.38))
    .clamp(260.0, 400.0);


          return Stack(
            fit: StackFit.expand,
            children: [
              // 🗺 MAP always fills full screen
              const Positioned.fill(child: HomeAirportSurfaceMap()),

              // ✅ Seam fade ONLY near hero bottom (not the whole screen!)
              Positioned(
                top: heroHeight - 90,
                left: 0,
                right: 0,
                height: 180,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.background.withOpacity(0.98),
                          colors.background.withOpacity(0.65),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // 🎥 HERO overlay (clipped blur so it doesn't blur map)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: heroHeight,
                child: _HeroOverlay(
                  heroImage: heroImage,
                  title: "SkyCaseFS",
                  line1: "${_utcTime()} UTC • ${_utcDate()}",
                  line2:
                      user?.hq?.icao != null
                          ? "HQ • ${user!.hq!.icao}"
                          : "HQ not set",
                  arrivalBar: _arrivalStatusBar(context), // 👈 ADD THIS
                ),
              ),

              // ✅ Safety: keep UI away from notches
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: const SizedBox(height: 0),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _arrivalStatusBar(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final arrival = context.watch<HomeArrivalProvider>();

    if (arrival.icao == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: colors.background.withOpacity(0.92),
        border: Border(
          bottom: BorderSide(
            color: Colors.cyanAccent.withOpacity(0.25),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flight_land, size: 16, color: Colors.cyanAccent),
          const SizedBox(width: 8),
          Text(
            "Arrived ${arrival.icao}",
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          if (arrival.parking != null) ...[
            const SizedBox(width: 10),
            Text(
              "• Gate ${arrival.parking}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onBackground.withOpacity(0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          
        ],
      ),
    );
  }
}

class _HeroOverlay extends StatelessWidget {
  final String heroImage;
  final String title;
  final String line1;
  final String line2;
  final Widget? arrivalBar;

  const _HeroOverlay({
    required this.heroImage,
    required this.title,
    required this.line1,
    required this.line2,
    this.arrivalBar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(heroImage, fit: BoxFit.cover),

        // dark gradient on top of hero
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.38),
                colors.background.withOpacity(0.92),
              ],
            ),
          ),
        ),

        // ✅ Blur only inside hero bounds
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withOpacity(0.06)),
          ),
        ),

        Positioned(
          left: 22,
          right: 22,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.onBackground,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                line1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onBackground.withOpacity(0.86),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: colors.onBackground.withOpacity(0.70),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    line2,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onBackground.withOpacity(0.72),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          left: 22,
          right: 22,
          bottom: -18,
          child: arrivalBar ?? const SizedBox.shrink(),
        ),
      ],
    );
  }
}
