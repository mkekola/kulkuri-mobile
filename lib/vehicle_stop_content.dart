import 'package:flutter/material.dart';

import 'departure_time.dart';
import 'digitransit.dart';
import 'theme.dart' as theme;
import 'vehicle_modes.dart';

Color _colorFromHex(String hex) => Color(int.parse(hex.substring(1), radix: 16) + 0xff000000);

class _PopupHeader extends StatelessWidget {
  final Widget title;
  final VoidCallback onClose;

  const _PopupHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: theme.lineStrong))),
      child: Row(
        children: [
          Expanded(child: title),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: theme.muted),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  final String mode;
  final String label;

  const _ModeBadge({required this.mode, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      constraints: const BoxConstraints(minWidth: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _colorFromHex(modeColor(mode)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(color: theme.onFill, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

// Vehicle tap - just mode/line for now. Route path, next stop, speed etc.
// would need more HFP fields and a bigger UI than this first pass covers.
class VehicleContent extends StatelessWidget {
  final String mode;
  final String? line;
  final VoidCallback onClose;

  const VehicleContent({super.key, required this.mode, this.line, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PopupHeader(
          onClose: onClose,
          title: Row(
            children: [
              _ModeBadge(mode: mode, label: line ?? '?'),
              const SizedBox(width: 10),
              Text(
                modeLabel(mode),
                style: const TextStyle(color: theme.text, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class StopContent extends StatelessWidget {
  final String name;
  final String? code;
  final Future<List<Departure>> departures;
  final VoidCallback onClose;

  const StopContent({
    super.key,
    required this.name,
    this.code,
    required this.departures,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PopupHeader(
          onClose: onClose,
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: theme.text, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              if (code != null) ...[
                const SizedBox(width: 8),
                Text(code!, style: const TextStyle(color: theme.muted, fontSize: 12)),
              ],
            ],
          ),
        ),
        FutureBuilder<List<Departure>>(
          future: departures,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final deps = snapshot.data ?? [];
            if (deps.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Ei tiedossa olevia lähtöjä.', style: TextStyle(color: theme.muted, fontSize: 13)),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: deps.map((d) => _DepartureRow(departure: d)).toList(),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DepartureRow extends StatelessWidget {
  final Departure departure;

  const _DepartureRow({required this.departure});

  @override
  Widget build(BuildContext context) {
    final delayText = formatDelay(departure.delaySeconds);
    final isLate = (departure.delaySeconds ?? 0) >= 60;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Row(
        children: [
          _ModeBadge(mode: departure.mode, label: departure.route),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  departure.headsign,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: theme.text, fontSize: 13),
                ),
                if (delayText != null)
                  Text(
                    delayText,
                    style: TextStyle(fontSize: 11, color: isLate ? theme.accentText : theme.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (departure.realtime) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: theme.accentText, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            formatDepartureCountdown(departure.departureAt, DateTime.now()),
            style: const TextStyle(color: theme.accentText, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
