import 'exercise_name.dart';

/// One exercise of the lifter's catalog: every official exercise plus their
/// own custom ones.
class CatalogExercise {
  const CatalogExercise({
    required this.id,
    required this.name,
    this.aliases = const [],
    this.isPredefined = false,
    this.retiredAt,
    this.createdAt,
  });

  /// A row of `exercises` as Supabase returns it.
  factory CatalogExercise.fromJson(Map<String, dynamic> json) => CatalogExercise(
    id: json['id'] as String,
    name: json['name'] as String,
    aliases: [for (final a in (json['aliases'] as List?) ?? const []) a as String],
    isPredefined: json['is_predefined'] == true,
    retiredAt: json['retired_at'] as String?,
    createdAt: json['created_at'] as String?,
  );

  final String id;
  final String name;

  /// Other names an official exercise answers to. Custom ones have none.
  final List<String> aliases;
  final bool isPredefined;
  final String? retiredAt;

  /// ISO 8601, so comparing the strings compares the times.
  final String? createdAt;

  /// Lower sorts first: active official, retired official, then custom.
  int get _rank => !isPredefined ? 2 : (retiredAt != null ? 1 : 0);
}

/// Finds catalog exercises by name or alias, in the order the server's
/// `find_exercise_for_user()` and the app's `findExerciseByName()` pick:
/// active official, retired official, then the oldest custom row.
class ExerciseCatalog {
  ExerciseCatalog(Iterable<CatalogExercise> exercises) {
    final ordered = [...exercises]
      ..sort((a, b) {
        final byRank = a._rank.compareTo(b._rank);
        return byRank != 0 ? byRank : (a.createdAt ?? '').compareTo(b.createdAt ?? '');
      });
    for (final e in ordered) {
      for (final name in [e.name, ...e.aliases]) {
        final key = normalizeExerciseName(name);
        if (key.isNotEmpty) _byName.putIfAbsent(key, () => e);
      }
    }
  }

  final _byName = <String, CatalogExercise>{};

  CatalogExercise? find(String? name) => name == null ? null : _byName[normalizeExerciseName(name)];
}
