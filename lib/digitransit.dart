import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'vehicle_modes.dart';

const _endpoint = 'https://api.digitransit.fi/routing/v2/hsl/gtfs/v1';

Future<T?> _graphql<T>(
  String query,
  Map<String, dynamic> variables,
  T Function(Map<String, dynamic> data) fromData,
) async {
  final apiKey = dotenv.env['DIGITRANSIT_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    debugPrint('[digitransit] no API key loaded from .env');
    return null;
  }

  final response = await http.post(
    Uri.parse(_endpoint),
    headers: {
      'Content-Type': 'application/json',
      'digitransit-subscription-key': apiKey,
    },
    body: jsonEncode({'query': query, 'variables': variables}),
  );
  if (response.statusCode != 200) {
    debugPrint('[digitransit] request failed: ${response.statusCode} ${response.body}');
    return null;
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  if (json['errors'] != null) {
    debugPrint('[digitransit] GraphQL errors: ${json['errors']}');
  }
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

class Departure {
  final String route;
  final String mode;
  final String headsign;
  final DateTime departureAt;
  final bool realtime;
  // Seconds late (negative = early) - only meaningful once `realtime` is true.
  final int? delaySeconds;

  Departure({
    required this.route,
    required this.mode,
    required this.headsign,
    required this.departureAt,
    required this.realtime,
    this.delaySeconds,
  });
}

const _stopDeparturesQuery = '''
query StopDepartures(\$id: String!, \$numberOfDepartures: Int!) {
  stop(id: \$id) {
    name
    code
    stoptimesWithoutPatterns(numberOfDepartures: \$numberOfDepartures) {
      scheduledDeparture
      realtimeDeparture
      realtime
      serviceDay
      headsign
      trip {
        route {
          shortName
          mode
        }
      }
    }
  }
}
''';

const _departuresLimit = 6;

// Next departures from a stop, most imminent first. `serviceDay` is midnight
// (epoch seconds) of the operating day; departure seconds can run past 86400
// for trips that started the previous day, so this still lands on the right
// real-world moment.
Future<List<Departure>> fetchStopDepartures(String gtfsId) async {
  final data = await _graphql(
    _stopDeparturesQuery,
    {'id': gtfsId, 'numberOfDepartures': _departuresLimit},
    (data) {
      final stop = data['stop'] as Map<String, dynamic>?;
      final stoptimes = (stop?['stoptimesWithoutPatterns'] as List<dynamic>?) ?? [];
      return stoptimes.cast<Map<String, dynamic>>().map((st) {
        final scheduled = st['scheduledDeparture'] as int;
        final realtimeDeparture = st['realtimeDeparture'] as int;
        final realtime = st['realtime'] as bool;
        final serviceDay = st['serviceDay'] as int;
        final route = st['trip']['route']['shortName'] as String?;
        final mode = st['trip']['route']['mode'] as String?;
        return Departure(
          route: route ?? '–',
          mode: normalizeMode(mode ?? ''),
          headsign: st['headsign'] as String? ?? '',
          departureAt: DateTime.fromMillisecondsSinceEpoch(
            (serviceDay + realtimeDeparture) * 1000,
          ),
          realtime: realtime,
          delaySeconds: realtime ? realtimeDeparture - scheduled : null,
        );
      }).toList();
    },
  );
  return data ?? [];
}
