String formatDuration(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  final hours = clamped.inHours;
  final minutes = clamped.inMinutes.remainder(60);
  final seconds = clamped.inSeconds.remainder(60);
  return '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}
