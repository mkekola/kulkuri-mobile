import 'package:flutter/material.dart';

import 'digitransit.dart';
import 'vehicle_modes.dart';

Color _colorFromHex(String hex) {
  return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
}

class VehicleSheetContent extends StatelessWidget {
  final String vehicleId;
  final String mode;
  final String? line;

  const VehicleSheetContent({super.key, required this.vehicleId, required this.mode, this.line});

  @override
  Widget build(BuildContext context) {
    final color = _colorFromHex(modeColors[mode] ?? defaultModeColor);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 18,
            child: Text(
              line ?? '?',
              style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              modeLabel(mode),
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class StopSheetContent extends StatelessWidget {
  final String name;
  final Future<List<Departure>> departures;

  const StopSheetContent({super.key, required this.name, required this.departures});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Departure>>(
            future: departures,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final deps = snapshot.data ?? [];
              if (deps.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Ei tulevia lähtöjä', style: TextStyle(color: Colors.white70)),
                );
              }
              return Column(
                children: deps.map((d) => _DepartureRow(departure: d)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DepartureRow extends StatelessWidget {
  final Departure departure;

  const _DepartureRow({required this.departure});

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(departure.departureAt).format(context);
    final delayMinutes = departure.delaySeconds != null ? (departure.delaySeconds! / 60).round() : 0;
    final delayText = departure.realtime && delayMinutes > 0 ? ' (+$delayMinutes min)' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text(
              departure.route,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(departure.headsign, style: const TextStyle(color: Colors.white)),
          ),
          Text('$time$delayText', style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
