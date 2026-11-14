import '../../../core/utils/exercise_name.dart';

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.isPredefined,
    this.userId,
    this.slug,
    this.aliases = const [],
    this.retiredAt,
    this.createdAt,
  });

  final String id;
  final String name;
  final bool isPredefined;
  final String? userId;

  /// An official exercise's permanent identity (`clean_and_jerk`), which
  /// survives a database rebuild where [id] doesn't. Null on custom ones.
  final String? slug;

  /// Other names an official exercise answers to ("C&J"). Always empty on
  /// custom ones.
  final List<String> aliases;

  /// Set when an official exercise has been retired: hidden from pickers, but
  /// still valid everywhere it's already used.
  final DateTime? retiredAt;

  /// Breaks ties between same-named rows the way the server does (oldest
  /// first). Null in tests that don't care.
  final DateTime? createdAt;

  bool get isRetired => retiredAt != null;

  /// Every normalized name this exercise answers to: its name plus aliases.
  Iterable<String> get matchKeys sync* {
    yield normalizeExerciseName(name);
    for (final a in aliases) {
      yield normalizeExerciseName(a);
    }
  }

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        name: json['name'] as String,
        isPredefined: json['is_predefined'] as bool,
        userId: json['user_id'] as String?,
        slug: json['slug'] as String?,
        aliases: [for (final a in (json['aliases'] as List?) ?? const []) a as String],
        retiredAt: json['retired_at'] == null ? null : DateTime.parse(json['retired_at'] as String),
        createdAt: json['created_at'] == null ? null : DateTime.parse(json['created_at'] as String),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Exercise && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
