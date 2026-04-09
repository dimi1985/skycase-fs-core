import 'package:flutter/material.dart';
import 'package:skycase/models/simlink_data.dart';
import 'package:skycase/models/aircraft_snapshot.dart';

class MapOverlay extends StatefulWidget {
  final SimLinkData simData;
  final bool show;
  final Widget Function(Widget) vibrate;

  const MapOverlay({
    super.key,
    required this.simData,
    required this.show,
    required this.vibrate,
  });

  @override
  State<MapOverlay> createState() => _MapOverlayState();
}

class _MapOverlayState extends State<MapOverlay> {
  late bool _visible;
  AircraftSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _visible = widget.show;
  }

  @override
  void didUpdateWidget(covariant MapOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.show != widget.show) {
      _visible = widget.show;
    }
  }

  bool get _hasBusPower => widget.simData.mainBusVolts > 5.0;
  bool get _avionicsOn => widget.simData.avionicsOn;
  bool get _shouldDim => _hasBusPower && !_avionicsOn;
  bool get _shouldBlackout => !_hasBusPower;

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return Stack(
      children: [
        Positioned(
          bottom: 50,
          left: 5,
          child: _applyPowerState(
            widget.vibrate(
              _g1000Hud(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _g1000Hud(BuildContext context) {
    final d = widget.simData;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.40),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _tinyBox("IAS", "${d.airspeed.toStringAsFixed(0)} kt"),
          _tinyCompass(d.heading),
          _tinyBox("ALT", "${d.altitude.toStringAsFixed(0)} ft"),
          _tinyBox("VS", "${d.verticalSpeed.toStringAsFixed(0)} fpm"),
          _tinyBox("FUEL", "${d.fuelGallons.toStringAsFixed(1)} gal"),
        ],
      ),
    );
  }

  Widget _tinyBox(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white30, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.cyanAccent,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tinyCompass(double heading) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white30, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "HDG",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Colors.cyanAccent,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.navigation,
                color: Colors.orangeAccent,
                size: 12,
              ),
              const SizedBox(width: 3),
              Text(
                "${heading.toStringAsFixed(0)}°",
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _applyPowerState(Widget child) {
    if (_shouldBlackout) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
          Colors.black,
          BlendMode.srcATop,
        ),
        child: child,
      );
    }

    if (_shouldDim) {
      return Opacity(
        opacity: 0.25,
        child: child,
      );
    }

    return child;
  }
}