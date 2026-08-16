import 'program_week.dart';

/// A reusable, multi-week training template a user authors once and can
/// "start" repeatedly (see `ProgramInstance`) — authoring-time data. A
/// `Workout` is still the only runtime/logged entity.
class Program {
  const Program({
    required this.id,
    required this.userId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.isPublic = false,
    this.isArchived = false,
    this.archivedAt,
    this.weeks = const [],
    this.ownerDisplayName,
  });

  final String id;
  final String userId;

  /// Author's `profiles.display_name`, present only when the query embedded
  /// `profiles(display_name)`. Render it through `ownerDisplayName()` in
  /// core/utils/owner_name.dart — null means "no name to show", not "no owner".
  final String? ownerDisplayName;
  final String name;
  final String? description;
  final bool isPublic;
  final bool isArchived;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProgramWeek> weeks;

  factory Program.fromJson(Map<String, dynamic> json) {
    final rawWeeks = (json['program_weeks'] as List?) ?? const [];
    final weeks = rawWeeks
        .map((e) => ProgramWeek.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return Program(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isPublic: (json['is_public'] as bool?) ?? false,
      isArchived: (json['is_archived'] as bool?) ?? false,
      archivedAt: json['archived_at'] != null
          ? DateTime.parse(json['archived_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      weeks: weeks,
      ownerDisplayName: (json['profiles'] as Map<String, dynamic>?)?['display_name'] as String?,
    );
  }
}
