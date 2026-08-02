/// One parsed percentage set produced by [parseSetBuilder].
class ParsedSet {
  const ParsedSet(this.targetReps, this.percentage);
  final int targetReps;
  final double percentage;
}

const _formatHelp = 'Use a format like "3 x 5 @ 80" or "4 x 2 @ 65-68-71-68"';

/// Parses set-builder shorthand into a list of percentage sets.
///
/// Grammar: `<sets> x <reps> @ <pct>[-<pct>...]` (case-insensitive, spaces ok).
/// A single percentage applies to every set; a hyphenated list must have one
/// value per set. Throws [FormatException] with a user-facing message.
List<ParsedSet> parseSetBuilder(String input) {
  final atParts = input.toLowerCase().split('@');
  if (atParts.length != 2) throw const FormatException(_formatHelp);

  final xParts = atParts[0].split('x');
  if (xParts.length != 2) throw const FormatException(_formatHelp);

  final sets = int.tryParse(xParts[0].trim());
  final reps = int.tryParse(xParts[1].trim());
  if (sets == null || sets < 1) throw const FormatException(_formatHelp);
  if (reps == null || reps < 1) throw const FormatException(_formatHelp);

  final pcts = atParts[1]
      .split('-')
      .map((t) => double.tryParse(t.trim()))
      .toList();
  if (pcts.any((p) => p == null)) throw const FormatException(_formatHelp);

  final List<double> perSet;
  if (pcts.length == 1) {
    perSet = List.filled(sets, pcts.first!);
  } else if (pcts.length == sets) {
    perSet = pcts.cast<double>();
  } else {
    throw FormatException('Expected 1 or $sets percentages after "@".');
  }

  return [for (final p in perSet) ParsedSet(reps, p)];
}
