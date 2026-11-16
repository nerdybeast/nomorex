/// What a set is for: warming up, the work itself, or cooling down. Stored as
/// `set_type` on `workout_sets` and `program_sets` (text, checked
/// `in ('warmup', 'working', 'cooldown')`, default `'working'`).
///
/// A set is a working set unless it's marked otherwise, and only working sets
/// count toward an exercise's "2/4 sets" progress.
enum SetType {
  warmup('warmup', 'Warm-up'),
  working('working', 'Working'),
  cooldown('cooldown', 'Cool-down');

  const SetType(this.dbValue, this.label);

  /// The value stored in the `set_type` column.
  final String dbValue;

  /// How the type reads in the UI ("Warm-up").
  final String label;

  /// The type stored as [value]. Anything unknown, including a type added on
  /// the server after this app version shipped, reads as [working], so an
  /// older app shows the set rather than failing.
  static SetType fromDb(Object? value) {
    for (final type in values) {
      if (type.dbValue == value) return type;
    }
    return working;
  }

  bool get isWorking => this == working;
}

/// The sets an exercise's "done/total sets" count covers: its working sets,
/// or every set when it has no working sets (an all-warm-up exercise), so the
/// count never reads "0/0".
List<T> countedSets<T>(List<T> sets, SetType Function(T set) typeOf) {
  final working = sets.where((s) => typeOf(s).isWorking).toList();
  return working.isEmpty ? sets : working;
}

/// The set-id order with just-added [newIds], all of [type], moved to the end
/// of their type's run: after every set of the same or an earlier type
/// (warm-ups, then working sets, then cool-downs), and before the rest. A
/// warm-up added after the working sets lands above them; within a type the
/// lifter's order is kept. [sorted] is the exercise's sets in position order,
/// the new ones included.
List<String> placeByType<T>(
  List<T> sorted, {
  required String Function(T set) idOf,
  required SetType Function(T set) typeOf,
  required List<String> newIds,
  required SetType type,
}) {
  final others = [for (final s in sorted) if (!newIds.contains(idOf(s))) s];
  final at = others.lastIndexWhere((s) => typeOf(s).index <= type.index) + 1;
  return [for (final s in others) idOf(s)]..insertAll(at, newIds);
}
