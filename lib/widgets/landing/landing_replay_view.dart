import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../models/flight_log.dart';
import 'landing_replay_canvas.dart';
import 'landing_replay_controls.dart';
import 'landing_replay_hud.dart';
import 'landing_replay_stats_panel.dart';

class LandingReplayView extends StatefulWidget {
  final Landing2d landing;

  const LandingReplayView({super.key, required this.landing});

  @override
  State<LandingReplayView> createState() => _LandingReplayViewState();
}

class _LandingReplayViewState extends State<LandingReplayView>
    with SingleTickerProviderStateMixin {
  late final List<Landing2dSample> _samples;
  late final Duration _totalDuration;
  late final int _touchdownIndex;
  late final List<LandingReplayPoint> _projectedPoints;

  Ticker? _ticker;
  bool _isPlaying = true;
  double _playbackSpeed = 1.0;
  Duration _currentReplayTime = Duration.zero;
  Duration? _lastTickElapsed;

  static const List<double> _speedOptions = [0.5, 1.0, 2.0, 4.0];

  @override
  void initState() {
    super.initState();
    _samples = _sortedSamples(widget.landing.samples);
    _touchdownIndex = _findTouchdownIndex(_samples);
    _totalDuration = _computeTotalDuration(_samples);
    _projectedPoints = _buildProjectedPoints(_samples, _touchdownIndex);
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _startTicker() {
    _ticker = createTicker((elapsed) {
      if (!_isPlaying) return;

      final previous = _lastTickElapsed;
      _lastTickElapsed = elapsed;
      if (previous == null) return;

      final delta = elapsed - previous;
      final scaled = Duration(
        microseconds: (delta.inMicroseconds * _playbackSpeed).round(),
      );

      final next = _currentReplayTime + scaled;
      if (next >= _totalDuration) {
        setState(() {
          _currentReplayTime = _totalDuration;
          _isPlaying = false;
        });
        _ticker?.stop();
        return;
      }

      setState(() {
        _currentReplayTime = next;
      });
    });

    _ticker?.start();
  }

  void _togglePlayPause() {
    if (_samples.length < 2) return;

    setState(() {
      _isPlaying = !_isPlaying;
      _lastTickElapsed = null;
    });

    if (_isPlaying) {
      _ticker?.start();
    } else {
      _ticker?.stop();
    }
  }

  void _restart() {
    setState(() {
      _currentReplayTime = Duration.zero;
      _isPlaying = true;
      _lastTickElapsed = null;
    });
    _ticker?.start();
  }

  void _setPlaybackSpeed(double value) {
    setState(() {
      _playbackSpeed = value;
      _lastTickElapsed = null;
    });
  }

  void _onScrub(double value) {
    final ms = (_totalDuration.inMilliseconds * value).round();
    setState(() {
      _currentReplayTime = Duration(milliseconds: ms);
      _lastTickElapsed = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_samples.length < 2 || _projectedPoints.length < 2) {
      return Center(
        child: Text(
          'Not enough landing replay data.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    final frame = _buildCurrentFrame();
    final progress =
        _totalDuration.inMilliseconds <= 0
            ? 0.0
            : (_currentReplayTime.inMilliseconds /
                    _totalDuration.inMilliseconds)
                .clamp(0.0, 1.0);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.55,
                child: LandingReplayCanvas(
                  points: _projectedPoints,
                  currentPosition: frame.position,
                  playedProgress: progress,
                  touchdownIndex: _touchdownIndex,
                  runway: widget.landing.runway,
                  planeHeadingRad: frame.headingRad,
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: LandingReplayHud(
                  runway: widget.landing.runway,
                  elapsed: frame.elapsed,
                  total: _totalDuration,
                  altitudeFt: frame.altitudeFt,
                  groundSpeedKt: frame.groundSpeedKt,
                  headingDeg: frame.headingDeg,
                  verticalSpeedFpm: frame.verticalSpeedFpm,
                  onGround: frame.onGround,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LandingReplayControls(
            isPlaying: _isPlaying,
            progress: progress,
            speed: _playbackSpeed,
            speedOptions: _speedOptions,
            onPlayPause: _togglePlayPause,
            onReplay: _restart,
            onScrub: _onScrub,
            onSpeedSelected: _setPlaybackSpeed,
          ),
          const SizedBox(height: 14),
          LandingReplayStatsPanel(landing: widget.landing, frame: frame),
        ],
      ),
    );
  }

  List<Landing2dSample> _sortedSamples(List<Landing2dSample> samples) {
    final copy = List<Landing2dSample>.from(samples);
    copy.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return copy;
  }

  Duration _computeTotalDuration(List<Landing2dSample> samples) {
    if (samples.length < 2) return const Duration(seconds: 1);
    final d = samples.last.timestamp.difference(samples.first.timestamp);
    if (d.inMilliseconds <= 0) {
      return Duration(milliseconds: math.max(1, samples.length * 250));
    }
    return d;
  }

  int _findTouchdownIndex(List<Landing2dSample> samples) {
    for (int i = 0; i < samples.length; i++) {
      if (samples[i].onGround) return i;
    }
    return samples.length - 1;
  }

  List<LandingReplayPoint> _buildProjectedPoints(
    List<Landing2dSample> samples,
    int touchdownIndex,
  ) {
    if (samples.length < 2) return const [];

    final td = samples[touchdownIndex];

    final localPoints = <_LocalPoint>[];
    for (final s in samples) {
      final local = _latLngToLocalMeters(
        lat: s.lat,
        lng: s.lng,
        refLat: td.lat,
        refLng: td.lng,
      );
      localPoints.add(_LocalPoint(x: local.dx, y: local.dy));
    }

    final rolloutBearing = _inferRolloutBearingRadians(samples, touchdownIndex);

    final rotated =
        localPoints.map((p) {
          final r = _rotatePoint(p.x, p.y, -rolloutBearing);
          return _LocalPoint(x: r.dx, y: r.dy);
        }).toList();

    final minX = rotated.map((e) => e.x).reduce(math.min);
    final maxX = rotated.map((e) => e.x).reduce(math.max);
    final minY = rotated.map((e) => e.y).reduce(math.min);
    final maxY = rotated.map((e) => e.y).reduce(math.max);

    final approachExtent = math.max(20.0, -math.min(0.0, minX));
    final rolloutExtent = math.max(20.0, math.max(0.0, maxX));
    final lateralExtent = math.max(10.0, math.max(maxY.abs(), minY.abs()));

    const canvasWidth = 1000.0;
    const canvasHeight = 650.0;

    const leftPad = 80.0;
    const rightPad = 60.0;
    const topPad = 70.0;
    const bottomPad = 80.0;

    const runwayLeft = 700.0;
    const runwayWidth = 220.0;
    const touchdownX = runwayLeft + (runwayWidth * 0.12);
    const touchdownY = 430.0;

    final leftAvailable = touchdownX - leftPad;
    final rightAvailable = (canvasWidth - rightPad) - touchdownX;
    final verticalAvailable = math.min(
      touchdownY - topPad,
      (canvasHeight - bottomPad) - touchdownY,
    );

    final scaleXApproach = leftAvailable / approachExtent;
    final scaleXRollout = rightAvailable / rolloutExtent;
    final scaleY = verticalAvailable / lateralExtent;

    final scale = math.max(
      0.1,
      math.min(scaleY, math.min(scaleXApproach, scaleXRollout)),
    );

    final points = <LandingReplayPoint>[];
    for (int i = 0; i < rotated.length; i++) {
      final p = rotated[i];
      points.add(
        LandingReplayPoint(
          x: touchdownX + (p.x * scale),
          y: touchdownY - (p.y * scale),
          elapsed: samples[i].timestamp.difference(samples.first.timestamp),
        ),
      );
    }

    return points;
  }

  _ReplayFrame _buildCurrentFrame() {
    if (_samples.length == 1) {
      return _ReplayFrame(
        elapsed: Duration.zero,
        position: _projectedPoints.first,
        headingRad: 0,
        headingDeg: _readHeading(_samples.first),
        altitudeFt: _readAltitude(_samples.first),
        groundSpeedKt: _readGroundSpeed(_samples.first),
        verticalSpeedFpm: _readVerticalSpeed(_samples.first),
        onGround: _samples.first.onGround,
      );
    }

    final targetMs = _currentReplayTime.inMilliseconds;

    if (targetMs <= 0) {
      return _frameFromIndex(0, 1, 0.0);
    }

    final totalMs = _totalDuration.inMilliseconds;
    if (targetMs >= totalMs) {
      return _frameFromIndex(_samples.length - 2, _samples.length - 1, 1.0);
    }

    for (int i = 0; i < _samples.length - 1; i++) {
      final aElapsed =
          _samples[i].timestamp
              .difference(_samples.first.timestamp)
              .inMilliseconds;
      final bElapsed =
          _samples[i + 1].timestamp
              .difference(_samples.first.timestamp)
              .inMilliseconds;

      if (targetMs >= aElapsed && targetMs <= bElapsed) {
        final span = math.max(1, bElapsed - aElapsed);
        final t = (targetMs - aElapsed) / span;
        return _frameFromIndex(i, i + 1, t.clamp(0.0, 1.0));
      }
    }

    return _frameFromIndex(_samples.length - 2, _samples.length - 1, 1.0);
  }

  _ReplayFrame _frameFromIndex(int aIndex, int bIndex, double t) {
    final a = _samples[aIndex];
    final b = _samples[bIndex];
    final pa = _projectedPoints[aIndex];
    final pb = _projectedPoints[bIndex];

    final x = _lerp(pa.x, pb.x, t);
    final y = _lerp(pa.y, pb.y, t);
    final dx = pb.x - pa.x;
    final dy = pb.y - pa.y;
    final headingRad =
        (dx.abs() < 0.001 && dy.abs() < 0.001)
            ? 0.0
            : math.atan2(dy, dx) + (math.pi / 2);

    return _ReplayFrame(
      elapsed: _currentReplayTime,
      position: LandingReplayPoint(x: x, y: y, elapsed: _currentReplayTime),
      headingRad: headingRad,
      headingDeg: _lerp(_readHeading(a), _readHeading(b), t),
      altitudeFt: _lerp(_readAltitude(a), _readAltitude(b), t),
      groundSpeedKt: _lerp(_readGroundSpeed(a), _readGroundSpeed(b), t),
      verticalSpeedFpm: _lerp(_readVerticalSpeed(a), _readVerticalSpeed(b), t),
      onGround: t < 0.5 ? a.onGround : b.onGround,
    );
  }

  double _lerp(double a, double b, double t) => a + ((b - a) * t);

  Offset _latLngToLocalMeters({
    required double lat,
    required double lng,
    required double refLat,
    required double refLng,
  }) {
    const metersPerDegLat = 111320.0;
    final metersPerDegLng = 111320.0 * math.cos(refLat * math.pi / 180.0);

    final dx = (lng - refLng) * metersPerDegLng;
    final dy = (lat - refLat) * metersPerDegLat;
    return Offset(dx, dy);
  }

  double _inferRolloutBearingRadians(
    List<Landing2dSample> samples,
    int touchdownIndex,
  ) {
    final td = samples[touchdownIndex];

    for (int i = touchdownIndex + 1; i < samples.length; i++) {
      final local = _latLngToLocalMeters(
        lat: samples[i].lat,
        lng: samples[i].lng,
        refLat: td.lat,
        refLng: td.lng,
      );
      if (local.distance > 3) {
        return math.atan2(local.dy, local.dx);
      }
    }

    if (touchdownIndex > 0) {
      final prev = samples[touchdownIndex - 1];
      final local = _latLngToLocalMeters(
        lat: td.lat,
        lng: td.lng,
        refLat: prev.lat,
        refLng: prev.lng,
      );
      if (local.distance > 1) {
        return math.atan2(local.dy, local.dx);
      }
    }

    final hdg = _readHeading(td) * math.pi / 180.0;
    final east = math.sin(hdg);
    final north = math.cos(hdg);
    return math.atan2(north, east);
  }

  Offset _rotatePoint(double x, double y, double angleRad) {
    final c = math.cos(angleRad);
    final s = math.sin(angleRad);
    return Offset((x * c) - (y * s), (x * s) + (y * c));
  }

  double _readAltitude(Landing2dSample sample) {
    final d = sample as dynamic;
    try {
      final v = d.altitude;
      if (v is num) return v.toDouble();
    } catch (_) {}
    try {
      final v = d.altitudeFt;
      if (v is num) return v.toDouble();
    } catch (_) {}
    try {
      final v = d.altitudeFeet;
      if (v is num) return v.toDouble();
    } catch (_) {}
    return 0;
  }

  double _readGroundSpeed(Landing2dSample sample) {
    final d = sample as dynamic;
    try {
      final v = d.groundSpeed;
      if (v is num) return v.toDouble();
    } catch (_) {}
    try {
      final v = d.groundspeed;
      if (v is num) return v.toDouble();
    } catch (_) {}
    try {
      final v = d.speed;
      if (v is num) return v.toDouble();
    } catch (_) {}
    return sample.airspeed.toDouble();
  }

  double _readHeading(Landing2dSample sample) {
    final d = sample as dynamic;
    try {
      final v = d.heading;
      if (v is num) return v.toDouble();
    } catch (_) {}
    return 0;
  }

  double _readVerticalSpeed(Landing2dSample sample) {
    final d = sample as dynamic;
    try {
      final v = d.verticalSpeed;
      if (v is num) return v.toDouble();
    } catch (_) {}
    try {
      final v = d.verticalSpeedFpm;
      if (v is num) return v.toDouble();
    } catch (_) {}
    return 0;
  }
}

class _ReplayFrame {
  final Duration elapsed;
  final LandingReplayPoint position;
  final double headingRad;
  final double headingDeg;
  final double altitudeFt;
  final double groundSpeedKt;
  final double verticalSpeedFpm;
  final bool onGround;

  const _ReplayFrame({
    required this.elapsed,
    required this.position,
    required this.headingRad,
    required this.headingDeg,
    required this.altitudeFt,
    required this.groundSpeedKt,
    required this.verticalSpeedFpm,
    required this.onGround,
  });
}

class _LocalPoint {
  final double x;
  final double y;

  const _LocalPoint({required this.x, required this.y});
}
