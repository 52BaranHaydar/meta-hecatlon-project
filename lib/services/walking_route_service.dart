import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class WalkingRouteException implements Exception {
  final String message;

  const WalkingRouteException(this.message);

  @override
  String toString() => message;
}

class WalkingRoute {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;

  const WalkingRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  int get walkingMinutes => (durationSeconds / 60).ceil();
}

class WalkingRouteService {
  static const _apiKey = String.fromEnvironment(
    'OPENROUTESERVICE_API_KEY',
    defaultValue: '',
  );

  static Future<WalkingRoute> getWalkingRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (_apiKey.isEmpty) {
      throw const WalkingRouteException(
        'Yaya rotası için OPENROUTESERVICE_API_KEY yapılandırılmalıdır.',
      );
    }

    final uri = Uri.https(
      'api.openrouteservice.org',
      '/v2/directions/foot-walking',
      {
        'api_key': _apiKey,
        'start': '${origin.longitude},${origin.latitude}',
        'end': '${destination.longitude},${destination.latitude}',
      },
    );

    late final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (error) {
      throw WalkingRouteException('Yaya rotası alınamadı: $error');
    }
    if (response.statusCode != 200) {
      throw WalkingRouteException(
        'Yaya rotası servisi HTTP ${response.statusCode} yanıtı verdi.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const WalkingRouteException('Yaya rotası yanıtı geçersiz.');
    }
    final features = decoded['features'];
    if (features is! List || features.isEmpty || features.first is! Map) {
      throw const WalkingRouteException('Yaya rotası bulunamadı.');
    }
    final feature = features.first as Map<String, dynamic>;
    final geometry = feature['geometry'];
    final properties = feature['properties'];
    if (geometry is! Map<String, dynamic> ||
        properties is! Map<String, dynamic>) {
      throw const WalkingRouteException('Yaya rotası yanıtı eksik.');
    }
    final coordinates = geometry['coordinates'];
    final summary = properties['summary'];
    if (coordinates is! List ||
        coordinates.length < 2 ||
        summary is! Map<String, dynamic> ||
        summary['distance'] is! num ||
        summary['duration'] is! num) {
      throw const WalkingRouteException('Yaya rotası bilgileri geçersiz.');
    }

    final points = <LatLng>[];
    for (final coordinate in coordinates) {
      if (coordinate is! List ||
          coordinate.length < 2 ||
          coordinate[0] is! num ||
          coordinate[1] is! num) {
        throw const WalkingRouteException('Yaya rotası koordinatları geçersiz.');
      }
      points.add(
        LatLng(
          (coordinate[1] as num).toDouble(),
          (coordinate[0] as num).toDouble(),
        ),
      );
    }

    return WalkingRoute(
      points: points,
      distanceMeters: (summary['distance'] as num).toDouble(),
      durationSeconds: (summary['duration'] as num).toDouble(),
    );
  }
}
