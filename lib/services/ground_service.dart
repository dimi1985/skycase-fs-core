import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:skycase/models/taxiway_label.dart';
import 'package:skycase/models/taxiway_segment.dart';

class GroundOverlayData {
  final List<TaxiwaySegment> lines;
  final List<TaxiwayLabel> labels;

  const GroundOverlayData({
    required this.lines,
    required this.labels,
  });
}

class _GroundTileBounds {
  final int x;
  final int y;
  final double north;
  final double south;
  final double east;
  final double west;

  const _GroundTileBounds({
    required this.x,
    required this.y,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  String get key => '$x:$y';
}

class _CachedGroundTile {
  final GroundOverlayData data;
  final DateTime fetchedAt;

  const _CachedGroundTile({
    required this.data,
    required this.fetchedAt,
  });

  bool get isFresh => DateTime.now().difference(fetchedAt).inMinutes < 30;
}

class GroundService {
  static const String baseUrl = 'http://38.242.241.46:3000/api/ground';

  // 0.02 worked, we keep it
  static const double _tileSizeDeg = 0.02;

  // Hard cap
  static const int _maxTilesPerFetch = 9;

  static final Map<String, _CachedGroundTile> _memoryCache = {};
  static final Set<String> _loadingTiles = {};
  static final Map<String, Future<GroundOverlayData>> _inFlightRequests = {};

  static Future<GroundOverlayData> fetchBounds({
    required double north,
    required double south,
    required double east,
    required double west,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/bounds?north=$north&south=$south&east=$east&west=$west',
    );

    

    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('Ground query failed: ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);

    if (decoded is! Map<String, dynamic>) {
      return const GroundOverlayData(lines: [], labels: []);
    }

    final rawLines = decoded['lines'];
    final rawLabels = decoded['labels'];

    final lines =
        rawLines is List
            ? rawLines
                .whereType<Map>()
                .map((e) => TaxiwaySegment.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : <TaxiwaySegment>[];

    final labels =
        rawLabels is List
            ? rawLabels
                .whereType<Map>()
                .map((e) => TaxiwayLabel.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : <TaxiwayLabel>[];

    return GroundOverlayData(lines: lines, labels: labels);
  }

  static Future<GroundOverlayData> fetchAroundCenter({
    required double centerLat,
    required double centerLon,
    int tileRadius = 1, // 1 = 3x3
  }) async {
    final tiles = _computeTilesAroundCenter(
      centerLat: centerLat,
      centerLon: centerLon,
      tileRadius: tileRadius,
    );

    final sortedTiles = List<_GroundTileBounds>.from(tiles)
      ..sort((a, b) {
        final da = _tileDistanceSq(a, centerLat, centerLon);
        final db = _tileDistanceSq(b, centerLat, centerLon);
        return da.compareTo(db);
      });

    final limitedTiles = sortedTiles.take(_maxTilesPerFetch).toList();

    final futures = limitedTiles.map(_getTileData).toList();
    final results = await Future.wait(futures);

    final allLines = <TaxiwaySegment>[];
    final allLabels = <TaxiwayLabel>[];

    for (final tileData in results) {
      allLines.addAll(tileData.lines);
      allLabels.addAll(tileData.labels);
    }

    return GroundOverlayData(
      lines: _dedupeLines(allLines),
      labels: _dedupeLabels(allLabels),
    );
  }

  static Future<GroundOverlayData> _getTileData(_GroundTileBounds tile) async {
    final cached = _memoryCache[tile.key];
    if (cached != null && cached.isFresh) {

      return cached.data;
    }

    final existingFuture = _inFlightRequests[tile.key];
    if (existingFuture != null) {
  
      return existingFuture;
    }

    _loadingTiles.add(tile.key);

    final future = (() async {
      try {
  

        final data = await fetchBounds(
          north: tile.north,
          south: tile.south,
          east: tile.east,
          west: tile.west,
        );

        _memoryCache[tile.key] = _CachedGroundTile(
          data: data,
          fetchedAt: DateTime.now(),
        );

        return data;
      } finally {
        _loadingTiles.remove(tile.key);
        _inFlightRequests.remove(tile.key);
      }
    })();

    _inFlightRequests[tile.key] = future;
    return future;
  }

  static List<_GroundTileBounds> _computeTilesAroundCenter({
    required double centerLat,
    required double centerLon,
    required int tileRadius,
  }) {
    final centerX = (centerLon / _tileSizeDeg).floor();
    final centerY = (centerLat / _tileSizeDeg).floor();

    final tiles = <_GroundTileBounds>[];

    for (int dy = -tileRadius; dy <= tileRadius; dy++) {
      for (int dx = -tileRadius; dx <= tileRadius; dx++) {
        final x = centerX + dx;
        final y = centerY + dy;

        final tileWest = x * _tileSizeDeg;
        final tileEast = (x + 1) * _tileSizeDeg;
        final tileSouth = y * _tileSizeDeg;
        final tileNorth = (y + 1) * _tileSizeDeg;

        tiles.add(
          _GroundTileBounds(
            x: x,
            y: y,
            north: tileNorth,
            south: tileSouth,
            east: tileEast,
            west: tileWest,
          ),
        );
      }
    }

    return tiles;
  }

  static double _tileDistanceSq(
    _GroundTileBounds tile,
    double centerLat,
    double centerLon,
  ) {
    final tileCenterLat = (tile.north + tile.south) / 2.0;
    final tileCenterLon = (tile.east + tile.west) / 2.0;

    final dLat = tileCenterLat - centerLat;
    final dLon = tileCenterLon - centerLon;

    return (dLat * dLat) + (dLon * dLon);
  }

  static List<TaxiwaySegment> _dedupeLines(List<TaxiwaySegment> items) {
    final seen = <String>{};
    final out = <TaxiwaySegment>[];

    for (final s in items) {
      final key =
          '${s.type}|${s.name}|'
          '${s.start.latitude.toStringAsFixed(6)},${s.start.longitude.toStringAsFixed(6)}|'
          '${s.end.latitude.toStringAsFixed(6)},${s.end.longitude.toStringAsFixed(6)}';

      if (seen.add(key)) {
        out.add(s);
      }
    }

    return out;
  }

  static List<TaxiwayLabel> _dedupeLabels(List<TaxiwayLabel> items) {
    final seen = <String>{};
    final out = <TaxiwayLabel>[];

    for (final l in items) {
      final key =
          '${l.name}|'
          '${l.position.latitude.toStringAsFixed(6)},${l.position.longitude.toStringAsFixed(6)}';

      if (seen.add(key)) {
        out.add(l);
      }
    }

    return out;
  }

  static void clearCache() {
    _memoryCache.clear();
    _loadingTiles.clear();
    _inFlightRequests.clear();
  }

  static int get cacheSize => _memoryCache.length;
}