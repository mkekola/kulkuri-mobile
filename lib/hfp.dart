import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'mqtt/mqtt_ws_client.dart';

const _brokerUrl = 'wss://mqtt.hsl.fi:443/';
const _topic = '/hfp/v2/journey/ongoing/vp/#';
const _flushInterval = Duration(seconds: 1);

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

// Live vehicle positions from HSL's public HFP feed - same broker/topic as
// the web app's hfp.ts, over a hand-rolled MQTT client (see mqtt_ws_client.dart
// for why). Simplified for this first pass: no stale-vehicle cleanup and no
// coupled-unit (double train) deduplication yet.
class VehiclePositionsClient {
  final void Function(List<VehiclePosition> vehicles) onUpdate;
  final _vehicles = <String, VehiclePosition>{};
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

    _flushTimer = Timer.periodic(_flushInterval, (_) {
      onUpdate(_vehicles.values.toList());
    });
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
        return;
      }

      _vehicles[vehicleId] = VehiclePosition(
        vehicleId: vehicleId,
        mode: mode,
        lat: lat,
        lng: long,
        route: vp['route'] as String?,
        line: desi,
      );
    } catch (e) {
      debugPrint('[hfp] failed to parse message on ${message.topic}: $e');
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _client.dispose();
  }
}
