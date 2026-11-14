/// One official exercise as the admin Exercises screen lists it
/// (`admin_list_exercises`).
class AdminExercise {
  const AdminExercise({
    required this.id,
    required this.slug,
    required this.name,
    required this.aliases,
    required this.usageCount,
    this.retiredAt,
  });

  final String id;

  /// Permanent, e.g. `clean_and_jerk`: what the catalog file keys on.
  final String slug;
  final String name;
  final List<String> aliases;

  /// Lifters who use it anywhere (PRs, workouts, programs, percentage bases).
  /// Only an unused exercise can be deleted.
  final int usageCount;
  final DateTime? retiredAt;

  bool get isRetired => retiredAt != null;
  bool get canDelete => usageCount == 0;

  factory AdminExercise.fromJson(Map<String, dynamic> json) => AdminExercise(
        id: json['id'] as String,
        slug: json['slug'] as String,
        name: json['name'] as String,
        aliases: [for (final a in (json['aliases'] as List?) ?? const []) a as String],
        usageCount: (json['usage_count'] as num).toInt(),
        retiredAt: json['retired_at'] == null ? null : DateTime.parse(json['retired_at'] as String),
      );
}

/// Slugs are lowercase letters and digits joined by single underscores. The
/// database refuses anything else; this lets the form say so first.
final kExerciseSlugPattern = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');

/// The longest name the database accepts.
const kMaxExerciseNameLength = 100;

/// A slug suggested from [name], by the same rule the catalog's slugs were
/// made with: "Clean & Jerk" → `clean_and_jerk`.
String suggestExerciseSlug(String name) => name
    .toLowerCase()
    .replaceAll('&', ' and ')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

/// "C&J, Clean and Jerk" → `['C&J', 'Clean and Jerk']`: trimmed, blanks
/// dropped. The database also drops repeats and any alias equal to the name.
List<String> parseAliases(String text) =>
    [for (final a in text.split(',')) if (a.trim().isNotEmpty) a.trim()];
