import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'mqtt/mqtt_ws_client.dart';

const _brokerUrl = 'wss://mqtt.hsl.fi:443/';
const _topic = '/hfp/v2/journey/ongoing/vp/#';
const _flushInterval = Duration(seconds: 1);
// A vehicle that hasn't sent a position in this long has likely ended its
// journey (HFP stops publishing for it) rather than just gone quiet.
const _staleAfter = Duration(seconds: 30);

class VehiclePosition {
  final String vehicleId;
  final String mode;
  final String? route;
  final String? line;
  final double lat;
  final double lng;

  VehiclePosition({
    required this.vehicleId,
    required this.mode,
    required this.lat,
    required this.lng,
    this.route,
    this.line,
  });
}

// Raw fields needed to group coupled units (see _journeyKey) - not exposed
// on VehiclePosition since nothing downstream needs them.
class _RawVehiclePosition {
  final String? route;
  final String? dir;
  final String? oday;
  final String? start;

  _RawVehiclePosition({this.route, this.dir, this.oday, this.start});
}

// Live vehicle positions from HSL's public HFP feed - same broker/topic as
// the web app's hfp.ts, over a hand-rolled MQTT client (see mqtt_ws_client.dart
// for why).
class VehiclePositionsClient {
  final void Function(List<VehiclePosition> vehicles) onUpdate;
  final _vehicles = <String, VehiclePosition>{};
  final _lastSeen = <String, DateTime>{};
  final _journeyKeys = <String, String?>{};
  final _client = MqttWsClient();
  Timer? _flushTimer;

  VehiclePositionsClient(this.onUpdate);

  Future<void> connect() async {
    final clientId = 'kulkuri-mobile-${Random().nextInt(1 << 32)}';

    try {
      await _client.connect(_brokerUrl, clientId: clientId);
    } catch (e) {
      debugPrint('[hfp] connect failed: $e');
      return;
    }
    debugPrint('[hfp] connected');

    _client.messages.listen(
      _onMessage,
      onError: (Object e) => debugPrint('[hfp] stream error: $e'),
    );
    _client.subscribe(_topic);
    debugPrint('[hfp] subscribed to $_topic');

    _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());
  }

  void _onMessage(MqttMessage message) {
    try {
      final json = jsonDecode(utf8.decode(message.payload)) as Map<String, dynamic>;
      final vp = json['VP'] as Map<String, dynamic>?;
      if (vp == null) return;

      final lat = (vp['lat'] as num?)?.toDouble();
      final long = (vp['long'] as num?)?.toDouble();
      if (lat == null || long == null) return;

      final parts = message.topic.split('/');
      final mode = parts.length > 6 ? parts[6] : 'unknown';
      final operator = parts.length > 7 ? parts[7] : '0';
      final vehicle = parts.length > 8 ? parts[8] : '0';
      final vehicleId = '$operator/$vehicle';

      // "X" is the out-of-service destination sign - not a real line.
      final desi = vp['desi'] as String?;
      if (desi == 'X') {
        _vehicles.remove(vehicleId);
        _lastSeen.remove(vehicleId);
        _journeyKeys.remove(vehicleId);
        return;
      }

      final route = vp['route'] as String?;
      final raw = _RawVehiclePosition(
        route: route,
        dir: vp['dir'] as String?,
        oday: vp['oday'] as String?,
        start: vp['start'] as String?,
      );

      _vehicles[vehicleId] = VehiclePosition(
        vehicleId: vehicleId,
        mode: mode,
        lat: lat,
        lng: long,
        route: route,
        line: desi,
      );
      _lastSeen[vehicleId] = DateTime.now();
      _journeyKeys[vehicleId] = _journeyKey(raw);
    } catch (e) {
      debugPrint('[hfp] failed to parse message on ${message.topic}: $e');
    }
  }

  // Trains and metros sometimes run as two physically coupled units sharing
  // one scheduled trip, each reporting its own HFP position - without this,
  // that's two markers sitting almost exactly on top of each other for what
  // a rider sees as a single train. Units on the same trip all report the
  // same route, direction, operating day and start time.
  String? _journeyKey(_RawVehiclePosition vp) {
    if (vp.route == null || vp.dir == null || vp.oday == null || vp.start == null) return null;
    return '${vp.route}/${vp.dir}/${vp.oday}/${vp.start}';
  }

  void _flush() {
    final now = DateTime.now();
    final staleIds = [
      for (final entry in _lastSeen.entries)
        if (now.difference(entry.value) > _staleAfter) entry.key,
    ];
    for (final id in staleIds) {
      _vehicles.remove(id);
      _lastSeen.remove(id);
      _journeyKeys.remove(id);
    }

    // One marker per journey: whichever coupled unit's vehicleId sorts
    // first represents the pair, consistently flush to flush (arrival order
    // on the MQTT topic isn't reliable) - the other unit's own position is
    // still tracked above, just not emitted as its own marker.
    final leaderByJourney = <String, String>{};
    for (final vehicleId in _vehicles.keys) {
      final key = _journeyKeys[vehicleId];
      if (key == null) continue;
      final currentLeader = leaderByJourney[key];
      if (currentLeader == null || vehicleId.compareTo(currentLeader) < 0) {
        leaderByJourney[key] = vehicleId;
      }
    }

    final result = <VehiclePosition>[];
    for (final entry in _vehicles.entries) {
      final key = _journeyKeys[entry.key];
      if (key != null && leaderByJourney[key] != entry.key) continue;
      result.add(entry.value);
    }

    onUpdate(result);
  }

  void dispose() {
    _flushTimer?.cancel();
    _client.dispose();
  }
}
