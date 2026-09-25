// Mirrors the web app's vehicleModes.ts MODE_COLORS - only what the map's
// vehicle dots need for now (badges, trunk-line orange, labels come later
// once there's UI chrome to put them in).
const modeColors = {
  'bus': '#3e8ef7',
  'tram': '#29c783',
  'metro': '#ff9f45',
  'train': '#b07cff',
  'ferry': '#35d6d6',
};

const defaultModeColor = '#9a9a9a';

const _modeLabels = {
  'bus': 'Bussi',
  'tram': 'Raitiovaunu',
  'metro': 'Metro',
  'train': 'Juna',
  'ferry': 'Lautta',
};

String modeLabel(String mode) => _modeLabels[mode] ?? mode;

String modeColor(String mode) => modeColors[mode] ?? defaultModeColor;

// Digitransit spells modes differently from HFP's topic segments (subway/rail
// vs metro/train); normalize so both feed the same modeColors/modeLabel.
const _digitransitModeAliases = {'subway': 'metro', 'rail': 'train'};

String normalizeMode(String mode) {
  final lower = mode.toLowerCase();
  return _digitransitModeAliases[lower] ?? lower;
}

/// A MapLibre `match` expression mapping each vehicle's `mode` property to
/// its mode color, for use as a data-driven `circleColor`.
List<Object> get modeColorMatchExpression => [
  'match',
  ['get', 'mode'],
  for (final entry in modeColors.entries) ...[entry.key, entry.value],
  defaultModeColor,
];
