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
