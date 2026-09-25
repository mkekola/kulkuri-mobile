import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

const _endpoint = 'https://api.digitransit.fi/routing/v2/hsl/gtfs/v1';

Future<T?> _graphql<T>(
  String query,
  Map<String, dynamic> variables,
  T Function(Map<String, dynamic> data) fromData,
) async {
  final apiKey = dotenv.env['DIGITRANSIT_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) return null;

  final response = await http.post(
    Uri.parse(_endpoint),
    headers: {
      'Content-Type': 'application/json',
      'digitransit-subscription-key': apiKey,
    },
    body: jsonEncode({'query': query, 'variables': variables}),
  );
  if (response.statusCode != 200) return null;

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final data = json['data'] as Map<String, dynamic>?;
  if (data == null) return null;
  return fromData(data);
}

class Stop {
  final String gtfsId;
  final String name;
  final String? code;
  final double lat;
  final double lon;
  final String? vehicleMode;

  Stop({
    required this.gtfsId,
    required this.name,
    required this.lat,
    required this.lon,
    this.code,
    this.vehicleMode,
  });

  factory Stop.fromJson(Map<String, dynamic> json) => Stop(
    gtfsId: json['gtfsId'] as String,
    name: json['name'] as String,
    code: json['code'] as String?,
    lat: (json['lat'] as num).toDouble(),
    lon: (json['lon'] as num).toDouble(),
    vehicleMode: json['vehicleMode'] as String?,
  );
}

const _stopsByBboxQuery = '''
query StopsByBbox(\$minLat: Float!, \$minLon: Float!, \$maxLat: Float!, \$maxLon: Float!) {
  stopsByBbox(minLat: \$minLat, minLon: \$minLon, maxLat: \$maxLat, maxLon: \$maxLon) {
    gtfsId
    name
    code
    lat
    lon
    vehicleMode
  }
}
''';

// Stops within the visible map area, for the always-on stop markers. Only
// called once the map is zoomed in enough that this stays a reasonable list
// (see main.dart's minStopsZoom).
Future<List<Stop>> fetchStopsInBounds({
  required double minLat,
  required double minLon,
  required double maxLat,
  required double maxLon,
}) async {
  final data = await _graphql(
    _stopsByBboxQuery,
    {'minLat': minLat, 'minLon': minLon, 'maxLat': maxLat, 'maxLon': maxLon},
    (data) => (data['stopsByBbox'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(Stop.fromJson)
        .toList(),
  );
  return data ?? [];
}
