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
    final isDark = theme.brightness == Brightness.dark;
    final user = context.watch<UserProvider>().user;

    const heroImages = [
      "assets/images/home_backgrounds/bg1.png",
      "assets/images/home_backgrounds/bg2.png",
    ];

    final heroImage =
        heroImages[(DateTime.now().minute ~/ 30) % heroImages.length];

    final hqLabel =
        user?.hq?.icao != null ? "HQ • ${user!.hq!.icao}" : "HQ not set";

    return Scaffold(
      backgroundColor: colors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;
          final topInset = MediaQuery.of(context).padding.top;

          final heroHeight = (h * (w < 520 ? 0.34 : 0.38)).clamp(250.0, 380.0);
          final horizontalPad = w < 700 ? 20.0 : 28.0;

          // more premium spacing
          final topClusterY = topInset + (w < 520 ? 28.0 : 34.0);
          final arrivalY = topClusterY + (w < 520 ? 116.0 : 128.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              const Positioned.fill(child: HomeAirportSurfaceMap()),

              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors:
                            isDark
                                ? [
                                  Colors.black.withOpacity(0.56),
                                  Colors.black.withOpacity(0.20),
                                  Colors.black.withOpacity(0.08),
                                  Colors.black.withOpacity(0.18),
                                  Colors.black.withOpacity(0.42),
                                ]
                                : [
                                  Colors.white.withOpacity(0.06),
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.06),
                                ],
                        stops: const [0.0, 0.18, 0.42, 0.72, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: heroHeight,
                child: IgnorePointer(
                  child: _AtmosphericHero(heroImage: heroImage),
                ),
              ),

              Positioned(
                top: topClusterY,
                left: horizontalPad,
                right: horizontalPad,
                child: _TopInfoCluster(
                  title: "SkyCaseFS",
                  line1: "${_utcTime()} UTC • ${_utcDate()}",
                  line2: hqLabel,
                ),
              ),

              Positioned(
                top: arrivalY,
                left: horizontalPad,
                right: horizontalPad,
                child: _ArrivalGlassCard(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AtmosphericHero extends StatelessWidget {
  const _AtmosphericHero({required this.heroImage});

  final String heroImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(heroImage, fit: BoxFit.cover, alignment: Alignment.center),

        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.transparent),
          ),
        ),

        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors:
                  isDark
                      ? [
                        Colors.black.withOpacity(0.16),
                        Colors.black.withOpacity(0.28),
                        colors.background.withOpacity(0.16),
                        Colors.transparent,
                      ]
                      : [
                        Colors.white.withOpacity(0.04),
                        Colors.white.withOpacity(0.02),
                        Colors.transparent,
                        Colors.transparent,
                      ],
              stops: const [0.0, 0.35, 0.72, 1.0],
            ),
          ),
        ),

        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors:
                  isDark
                      ? [
                        Colors.black.withOpacity(0.18),
                        Colors.transparent,
                        Colors.black.withOpacity(0.08),
                      ]
                      : [
                        Colors.white.withOpacity(0.03),
                        Colors.transparent,
                        Colors.transparent,
                      ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopInfoCluster extends StatelessWidget {
  const _TopInfoCluster({
    required this.title,
    required this.line1,
    required this.line2,
  });

  final String title;
  final String line1;
  final String line2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final glassColor =
        isDark
            ? colors.surface.withOpacity(0.20)
            : colors.surface.withOpacity(0.68);

    final borderColor =
        isDark
            ? colors.primary.withOpacity(0.14)
            : colors.outline.withOpacity(0.18);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color:
                    isDark
                        ? Colors.black.withOpacity(0.26)
                        : colors.shadow.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: colors.onSurface,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                line1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface.withOpacity(0.82),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: colors.onSurface.withOpacity(0.66),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      line2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withOpacity(0.72),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrivalGlassCard extends StatelessWidget {
  const _ArrivalGlassCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final arrival = context.watch<HomeArrivalProvider>();

    if (arrival.icao == null) {
      return const SizedBox.shrink();
    }

    final glassColor =
        isDark
            ? colors.surface.withOpacity(0.22)
            : colors.surface.withOpacity(0.74);

    final accentColor = colors.primary;
    final borderColor =
        isDark ? accentColor.withOpacity(0.22) : accentColor.withOpacity(0.18);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDark
                            ? Colors.black.withOpacity(0.22)
                            : colors.shadow.withOpacity(0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accentColor.withOpacity(isDark ? 0.16 : 0.12),
                      border: Border.all(
                        color: accentColor.withOpacity(0.26),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.flight_land,
                      size: 18,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Arrival Registered",
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSurface.withOpacity(0.64),
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              arrival.icao!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colors.onSurface,
                                letterSpacing: 0.6,
                              ),
                            ),
                            if (arrival.parking != null)
                              Text(
                                "• Gate ${arrival.parking}",
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface.withOpacity(0.76),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
