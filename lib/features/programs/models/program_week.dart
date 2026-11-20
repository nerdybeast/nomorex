import 'program_day.dart';

/// The most days a week holds. A week is a calendar week: it takes 7 days of
/// a run's schedule however many it holds. The database enforces the limit
/// (`enforce_program_week_day_limit`).
const kMaxDaysPerWeek = 7;

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

  /// Whether the week has its [kMaxDaysPerWeek] days, so no day can be added.
  bool get isFull => days.length >= kMaxDaysPerWeek;

  /// [weekIndex] is the week's 0-based place in the program, which with each
  /// day's place in the week sets [ProgramDay.dayOffset].
  factory ProgramWeek.fromJson(Map<String, dynamic> json, {int weekIndex = 0}) {
    final rawDays = ((json['program_days'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList()
      ..sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    final days = [
      for (var i = 0; i < rawDays.length; i++)
        ProgramDay.fromJson(rawDays[i], dayOffset: weekIndex * kMaxDaysPerWeek + i),
    ];
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
