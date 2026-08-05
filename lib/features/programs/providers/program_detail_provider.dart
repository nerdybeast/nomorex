import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program.dart';
import '../utils/parsed_program_set.dart';
import '../../auth/providers/auth_provider.dart';
import 'programs_provider.dart';

part 'program_detail_provider.g.dart';

@Riverpod(keepAlive: true)
class ProgramDetailNotifier extends _$ProgramDetailNotifier {
  SupabaseClient get _db => Supabase.instance.client;
  String get _userId => _db.auth.currentUser!.id;

  @override
  Future<Program> build(String programId) async {
    ref.watch(authStateProvider);
    final data = await _db
        .from('programs')
        .select('*, program_weeks(*, program_days(*, program_exercises('
            '*, exercises(name), program_sets(*, exercises(name)))))')
        .eq('id', programId)
        .single();
    return Program.fromJson(data);
  }

  Future<void> _refresh() async {
    ref.invalidateSelf();
    await future;
  }

  // ---- Weeks ----

  Future<void> addWeek({String? label, String? notes}) async {
    final current = await future;
    await _db.from('program_weeks').insert({
      'program_id': programId,
      'user_id': _userId,
      'week_number': current.weeks.length + 1,
      'position': current.weeks.length,
      if (label != null && label.isNotEmpty) 'label': label,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
    await _refresh();
  }

  Future<void> removeWeek(String weekId) async {
    await _db.from('program_weeks').delete().eq('id', weekId);
    await _refresh();
  }

  Future<void> updateWeekMeta(String weekId, {String? label, String? notes}) async {
    await _db.from('program_weeks').update({
      'label': (label != null && label.isEmpty) ? null : label,
      'notes': (notes != null && notes.isEmpty) ? null : notes,
    }).eq('id', weekId);
    await _refresh();
  }

  /// Reassigns the position/week_number slots already held by [orderedWeekIds]
  /// in the new order. A two-phase (negative, then final) update dodges the
  /// unique(program_id, week_number) constraint, which plain sequential
  /// single-row updates would otherwise transiently violate on a cyclic swap.
  Future<void> reorderWeeks(List<String> orderedWeekIds) async {
    final current = await future;
    final positions = (orderedWeekIds
            .map((id) => current.weeks.firstWhere((w) => w.id == id).position)
            .toList()
          ..sort());
    final weekNumbers = (orderedWeekIds
            .map((id) => current.weeks.firstWhere((w) => w.id == id).weekNumber)
            .toList()
          ..sort());
    for (var i = 0; i < orderedWeekIds.length; i++) {
      await _db
          .from('program_weeks')
          .update({'position': -(i + 1), 'week_number': -(i + 1)}).eq('id', orderedWeekIds[i]);
    }
    for (var i = 0; i < orderedWeekIds.length; i++) {
      await _db
          .from('program_weeks')
          .update({'position': positions[i], 'week_number': weekNumbers[i]}).eq(
              'id', orderedWeekIds[i]);
    }
    await _refresh();
  }

  // ---- Days ----

  Future<void> addDay(String weekId, {required String title, bool isRestDay = false}) async {
    final current = await future;
    final week = current.weeks.firstWhere((w) => w.id == weekId);
    final totalDays = current.weeks.fold<int>(0, (sum, w) => sum + w.days.length);
    await _db.from('program_days').insert({
      'program_id': programId,
      'program_week_id': weekId,
      'user_id': _userId,
      'day_number': week.days.length + 1,
      'title': title,
      'is_rest_day': isRestDay,
      'position': totalDays,
    });
    await _refresh();
  }

  Future<void> removeDay(String dayId) async {
    await _db.from('program_days').delete().eq('id', dayId);
    await _refresh();
  }

  Future<void> updateDayMeta(
    String dayId, {
    String? title,
    bool? isRestDay,
    String? notes,
  }) async {
    final values = <String, dynamic>{};
    if (title != null) values['title'] = title;
    if (isRestDay != null) values['is_rest_day'] = isRestDay;
    if (notes != null) values['notes'] = notes.isEmpty ? null : notes;
    if (values.isEmpty) return;
    await _db.from('program_days').update(values).eq('id', dayId);
    await _refresh();
  }

  /// Same two-phase trick as [reorderWeeks], for the unique(program_id, position)
  /// constraint on program_days. Only reorders within the set of ids passed in
  /// (typically a single week's days); day_number is left untouched since it's
  /// not unique and isn't display-order-derived.
  Future<void> reorderDays(List<String> orderedDayIds) async {
    final current = await future;
    final allDays = current.weeks.expand((w) => w.days).toList();
    final positions = (orderedDayIds
            .map((id) => allDays.firstWhere((d) => d.id == id).position)
            .toList()
          ..sort());
    for (var i = 0; i < orderedDayIds.length; i++) {
      await _db.from('program_days').update({'position': -(i + 1)}).eq('id', orderedDayIds[i]);
    }
    for (var i = 0; i < orderedDayIds.length; i++) {
      await _db.from('program_days').update({'position': positions[i]}).eq('id', orderedDayIds[i]);
    }
    await _refresh();
  }

  // ---- Exercises ----

  Future<void> addExercise(String dayId, String exerciseId) async {
    final current = await future;
    final day = current.weeks.expand((w) => w.days).firstWhere((d) => d.id == dayId);
    await _db.from('program_exercises').insert({
      'program_day_id': dayId,
      'user_id': _userId,
      'exercise_id': exerciseId,
      'position': day.exercises.length,
    });
    await _refresh();
  }

  Future<void> removeExercise(String programExerciseId) async {
    await _db.from('program_exercises').delete().eq('id', programExerciseId);
    await _refresh();
  }

  Future<void> updateExerciseNotes(String programExerciseId, String? notes) async {
    await _db
        .from('program_exercises')
        .update({'notes': (notes != null && notes.isEmpty) ? null : notes})
        .eq('id', programExerciseId);
    await _refresh();
  }

  // ---- Sets ----

  Future<void> addPercentageSets(
    String programExerciseId,
    List<ParsedProgramSet> parsed,
  ) async {
    if (parsed.isEmpty) return;
    final current = await future;
    final ex = current.weeks
        .expand((w) => w.days)
        .expand((d) => d.exercises)
        .firstWhere((e) => e.id == programExerciseId);
    var pos = ex.sets.length;
    await _db.from('program_sets').insert([
      for (final p in parsed)
        {
          'program_exercise_id': programExerciseId,
          'user_id': _userId,
          'position': pos++,
          'target_reps': p.targetReps,
          'weight_mode': 'percentage',
          'percentage': p.percentage,
          'basis_exercise_id': p.basisExerciseId,
        },
    ]);
    await _refresh();
  }

  Future<void> addAbsoluteSets(
    String programExerciseId, {
    required int sets,
    required int reps,
    required double weightKg,
  }) async {
    if (sets <= 0) return;
    final current = await future;
    final ex = current.weeks
        .expand((w) => w.days)
        .expand((d) => d.exercises)
        .firstWhere((e) => e.id == programExerciseId);
    var pos = ex.sets.length;
    await _db.from('program_sets').insert([
      for (var i = 0; i < sets; i++)
        {
          'program_exercise_id': programExerciseId,
          'user_id': _userId,
          'position': pos++,
          'target_reps': reps,
          'weight_mode': 'absolute',
          'absolute_weight_kg': weightKg,
        },
    ]);
    await _refresh();
  }

  Future<void> deleteSet(String setId) async {
    await _db.from('program_sets').delete().eq('id', setId);
    await _refresh();
  }

  // ---- Program meta ----

  Future<void> updateProgramMeta({String? name, String? description}) async {
    final values = <String, dynamic>{};
    if (name != null && name.isNotEmpty) values['name'] = name;
    if (description != null) values['description'] = description.isEmpty ? null : description;
    if (values.isEmpty) return;
    await _db.from('programs').update(values).eq('id', programId);
    ref.invalidate(programsProvider);
    await _refresh();
  }

  Future<void> updateVisibility(bool isPublic) async {
    await _db.from('programs').update({'is_public': isPublic}).eq('id', programId);
    await _refresh();
  }
}
