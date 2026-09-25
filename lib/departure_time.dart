// Mirrors the web app's departureTime.ts. Uses the device's local time
// rather than forcing Europe/Helsinki - fine as long as the phone testing
// this is actually in Finland, unlike the web app which has no such
// guarantee about its visitors.

// Departures under an hour away read as a countdown; anything further out
// reads as a clock time instead, since a raw minute count stops being a
// useful unit much past that.
String formatDepartureCountdown(DateTime departureAt, DateTime now) {
  final minutes = (departureAt.difference(now).inSeconds / 60).round();
  if (minutes <= 0) return 'nyt';
  if (minutes < 60) return '$minutes min';
  final hh = departureAt.hour.toString().padLeft(2, '0');
  final mm = departureAt.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

// HSL's own apps don't flag anything within about a minute either way as
// late/early - reporting it down to the second would just be noise from
// ordinary GPS/traffic-light jitter, not a real schedule deviation.
const _onTimeToleranceSeconds = 60;

// null means no delay data at all (a departure with no live estimate yet) -
// distinct from being on time, which still returns a string.
String? formatDelay(int? delaySeconds) {
  if (delaySeconds == null) return null;
  if (delaySeconds.abs() < _onTimeToleranceSeconds) return 'Ajallaan';
  final minutes = (delaySeconds.abs() / 60).round();
  return delaySeconds > 0 ? '$minutes min myöhässä' : '$minutes min etuajassa';
}
