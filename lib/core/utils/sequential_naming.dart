/// Returns "$prefix N" where N is one more than the highest N found among
/// [existingNames] matching "$prefix" followed by an integer (case-
/// insensitive, whitespace-trimmed). Falls back to "$prefix 1" when nothing
/// matches.
String nextSequentialName(Iterable<String> existingNames, String prefix) {
  final pattern = RegExp('^${RegExp.escape(prefix)} (\\d+)\$', caseSensitive: false);
  var maxN = 0;
  for (final name in existingNames) {
    final match = pattern.firstMatch(name.trim());
    if (match == null) continue;
    final n = int.tryParse(match.group(1)!) ?? 0;
    if (n > maxN) maxN = n;
  }
  return '$prefix ${maxN + 1}';
}
