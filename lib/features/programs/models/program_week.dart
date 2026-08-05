import 'program_day.dart';

/// A labeled group of days within a program (e.g. "Loading Week 2/6").
class ProgramWeek {
  const ProgramWeek({
    required this.id,
    required this.programId,
    required this.weekNumber,
    required this.position,
    this.label,
    this.notes,
    this.days = const [],
  });

  final String id;
  final String programId;
  final int weekNumber;
  final String? label;
  final String? notes;
  final int position;
  final List<ProgramDay> days;

  factory ProgramWeek.fromJson(Map<String, dynamic> json) {
    final rawDays = (json['program_days'] as List?) ?? const [];
    final days = rawDays
        .map((e) => ProgramDay.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return ProgramWeek(
      id: json['id'] as String,
      programId: json['program_id'] as String,
      weekNumber: json['week_number'] as int,
      label: json['label'] as String?,
      notes: json['notes'] as String?,
      position: json['position'] as int,
      days: days,
    );
  }
}
