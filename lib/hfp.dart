import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

const _brokerUrl = 'wss://mqtt.hsl.fi';
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
// the web app's hfp.ts. Simplified for this first pass: no stale-vehicle
// cleanup and no coupled-unit (double train) deduplication yet.
class VehiclePositionsClient {
  final void Function(List<VehiclePosition> vehicles) onUpdate;
  final _vehicles = <String, VehiclePosition>{};
  MqttServerClient? _client;
  Timer? _flushTimer;

  VehiclePositionsClient(this.onUpdate);

  Future<void> connect() async {
    final clientId = 'kulkuri-mobile-${Random().nextInt(1 << 32)}';
    final client = MqttServerClient(_brokerUrl, clientId)
      ..useWebSocket = true
      ..port = 443
      ..keepAlivePeriod = 30
      ..logging(on: false);
    _client = client;

    try {
      await client.connect();
    } catch (_) {
      client.disconnect();
      return;
    }

    client.subscribe(_topic, MqttQos.atMostOnce);
    client.updates?.listen(_onMessage);

    _flushTimer = Timer.periodic(_flushInterval, (_) {
      onUpdate(_vehicles.values.toList());
    });
  }

  void _onMessage(List<MqttReceivedMessage<MqttMessage>> messages) {
    for (final message in messages) {
      try {
        final publish = message.payload as MqttPublishMessage;
        final json =
            jsonDecode(MqttPublishPayload.bytesToStringAsString(publish.payload.message))
                as Map<String, dynamic>;
        final vp = json['VP'] as Map<String, dynamic>?;
        if (vp == null) continue;

        final lat = (vp['lat'] as num?)?.toDouble();
        final long = (vp['long'] as num?)?.toDouble();
        if (lat == null || long == null) continue;

        final parts = message.topic.split('/');
        final mode = parts.length > 6 ? parts[6] : 'unknown';
        final operator = parts.length > 7 ? parts[7] : '0';
        final vehicle = parts.length > 8 ? parts[8] : '0';
        final vehicleId = '$operator/$vehicle';

        // "X" is the out-of-service destination sign - not a real line.
        final desi = vp['desi'] as String?;
        if (desi == 'X') {
          _vehicles.remove(vehicleId);
          continue;
        }

        _vehicles[vehicleId] = VehiclePosition(
          vehicleId: vehicleId,
          mode: mode,
          lat: lat,
          lng: long,
          route: vp['route'] as String?,
          line: desi,
        );
      } catch (_) {
        // Ignore malformed messages.
      }
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _client?.disconnect();
  }
}
