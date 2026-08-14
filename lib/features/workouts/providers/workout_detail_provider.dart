import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout.dart';
import '../utils/parsed_set.dart';
import '../utils/workout_copier.dart';
import '../../auth/providers/auth_provider.dart';
import 'finished_workouts_provider.dart';
import 'in_progress_workouts_provider.dart';
import 'workouts_provider.dart';

part 'workout_detail_provider.g.dart';

@Riverpod(keepAlive: true)
class WorkoutDetailNotifier extends _$WorkoutDetailNotifier {
  SupabaseClient get _db => Supabase.instance.client;
  String get _userId => _db.auth.currentUser!.id;

  @override
  Future<Workout> build(String workoutId) async {
    ref.watch(authStateProvider);
    final data = await _db
        .from('workouts')
        .select('*, workout_exercises(*, exercises(name), workout_sets(*, exercises(name)))')
        .eq('id', workoutId)
        .single();
    return Workout.fromJson(data);
  }

  Future<void> _refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> addExercise(String exerciseId) async {
    final current = await future;
    final nextPos = current.exercises.length;
    await _db.from('workout_exercises').insert({
      'workout_id': workoutId,
      'user_id': _userId,
      'exercise_id': exerciseId,
      'position': nextPos,
    });
    await _refresh();
  }

  Future<void> removeExercise(String workoutExerciseId) async {
    await _db.from('workout_exercises').delete().eq('id', workoutExerciseId);
    await _refresh();
  }

  Future<void> updateExerciseNotes(String workoutExerciseId, String? notes) async {
    await _db
        .from('workout_exercises')
        .update({'notes': (notes != null && notes.isEmpty) ? null : notes})
        .eq('id', workoutExerciseId);
    await _refresh();
  }

  Future<void> addPercentageSets(
      String workoutExerciseId, List<ParsedSet> parsed) async {
    if (parsed.isEmpty) return;
    final current = await future;
    final ex = current.exercises.firstWhere((e) => e.id == workoutExerciseId);
    var pos = ex.sets.length;
    await _db.from('workout_sets').insert([
      for (final p in parsed)
        {
          'workout_exercise_id': workoutExerciseId,
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
      String workoutExerciseId, {
      required int sets,
      required int reps,
      required double weightKg,
      }) async {
    if (sets <= 0) return;
    final current = await future;
    final ex = current.exercises.firstWhere((e) => e.id == workoutExerciseId);
    var pos = ex.sets.length;
    await _db.from('workout_sets').insert([
      for (var i = 0; i < sets; i++)
        {
          'workout_exercise_id': workoutExerciseId,
          'user_id': _userId,
          'position': pos++,
          'target_reps': reps,
          'weight_mode': 'absolute',
          'absolute_weight_kg': weightKg,
        },
    ]);
    await _refresh();
  }

  Future<void> updateSet(String setId, Map<String, dynamic> values) async {
    await _db.from('workout_sets').update(values).eq('id', setId);
    await _refresh();
  }

  Future<void> deleteSet(String setId) async {
    await _db.from('workout_sets').delete().eq('id', setId);
    await _refresh();
  }

  Future<void> setCompleted(String setId, bool completed) async {
    await _db.from('workout_sets').update({'completed': completed}).eq('id', setId);
    await _refresh();
  }

  Future<void> logActual(String setId, {double? weightKg, int? reps}) async {
    await _db.from('workout_sets').update({
      'actual_weight_kg': weightKg,
      'actual_reps': reps,
    }).eq('id', setId);
    await _refresh();
  }

  Future<void> updateVisibility(bool isPublic) async {
    await _db.from('workouts').update({'is_public': isPublic}).eq('id', workoutId);
    ref.invalidate(workoutsProvider);
    await _refresh();
  }

  Future<void> updateTitle(String title) async {
    await _db.from('workouts').update({'title': title}).eq('id', workoutId);
    ref.invalidate(workoutsProvider);
    await _refresh();
  }

  // "Description" in the UI maps to the pre-existing `notes` column.
  Future<void> updateDescription(String? description) async {
    await _db
        .from('workouts')
        .update({'notes': (description != null && description.isEmpty) ? null : description})
        .eq('id', workoutId);
    await _refresh();
  }

  Future<void> startWorkout() async {
    await _db.rpc('start_workout_session', params: {'p_workout_id': workoutId});
    ref.invalidate(inProgressWorkoutsProvider);
    await _refresh();
  }

  Future<void> pauseWorkout() async {
    await _db.rpc('pause_workout_session', params: {'p_workout_id': workoutId});
    await _refresh();
  }

  Future<void> resumeWorkout() async {
    await _db.rpc('resume_workout_session', params: {'p_workout_id': workoutId});
    await _refresh();
  }

  Future<void> finishWorkout({String? sessionNotes}) async {
    final current = await future;
    await _db.rpc('finish_workout_session', params: {
      'p_workout_id': workoutId,
      'p_session_notes': sessionNotes,
    });

    // Eagerly materialize the next not-started instance for this group, so
    // the Workouts list always has a live/actionable row to show instead of
    // this now-frozen completion. Standalone workouts only — a
    // program-materialized day doesn't spawn a standalone copy of itself;
    // repeating a whole program goes through starting a new program
    // instance instead. Skipped if a live sibling already exists (e.g. this
    // finish is racing another tab, or repeatWorkout() already made one).
    if (current.programInstanceId == null) {
      final liveSibling = await _db
          .from('workouts')
          .select('id')
          .eq('user_id', _userId)
          .eq('workout_group_id', current.workoutGroupId)
          .inFilter('status', ['not_started', 'in_progress', 'paused']).maybeSingle();
      if (liveSibling == null) {
        final nextWorkout = await _db.from('workouts').insert({
          'user_id': _userId,
          'title': current.title,
          'date': DateTime.now().toIso8601String().split('T').first,
          if (current.notes != null) 'notes': current.notes,
          'workout_group_id': current.workoutGroupId,
        }).select('id').single();
        await copyWorkoutContents(
          _db,
          userId: _userId,
          sourceExercises: current.exercises,
          targetWorkoutId: nextWorkout['id'] as String,
        );
      }
    }

    ref.invalidate(workoutsProvider);
    ref.invalidate(inProgressWorkoutsProvider);
    ref.invalidate(finishedWorkoutsProvider);
    await _refresh();
  }

  Future<void> discardSession() async {
    await _db.rpc('discard_workout_session', params: {'p_workout_id': workoutId});
    ref.invalidate(inProgressWorkoutsProvider);
    await _refresh();
  }

  /// Starts another instance of this workout's group. Reuses an existing
  /// not-started sibling if one's already there (the common case — finishing
  /// a workout eagerly creates the next instance, see finishWorkout()) rather
  /// than creating a duplicate; only falls back to creating+copying a new row
  /// when no sibling exists at all (e.g. a workout finished before eager
  /// creation existed, or a program-materialized repeat, which doesn't get
  /// one). Throws a [StateError] instead of creating a second in-progress
  /// instance of the same logical workout — checked proactively, then backed
  /// by the DB's partial unique index as a race guard.
  Future<String> repeatWorkout() async {
    final current = await future;
    final groupId = current.workoutGroupId;

    final existing = await _db
        .from('workouts')
        .select('id, status')
        .eq('user_id', _userId)
        .eq('workout_group_id', groupId)
        .inFilter('status', ['not_started', 'in_progress', 'paused']).maybeSingle();

    String targetId;
    final reusingExisting = existing != null;
    if (existing != null) {
      final status = existing['status'] as String;
      if (status != 'not_started') {
        throw StateError('This workout is already in progress.');
      }
      targetId = existing['id'] as String;
    } else {
      final newWorkout = await _db.from('workouts').insert({
        'user_id': _userId,
        'title': current.title,
        'date': DateTime.now().toIso8601String().split('T').first,
        if (current.notes != null) 'notes': current.notes,
        'workout_group_id': groupId,
      }).select('id').single();
      targetId = newWorkout['id'] as String;

      await copyWorkoutContents(
        _db,
        userId: _userId,
        sourceExercises: current.exercises,
        targetWorkoutId: targetId,
      );
    }

    try {
      await _db.rpc('start_workout_session', params: {'p_workout_id': targetId});
    } on PostgrestException catch (e) {
      if (!reusingExisting) {
        await _db.from('workouts').delete().eq('id', targetId);
      }
      if (e.code == '23505') {
        throw StateError('This workout is already in progress.');
      }
      rethrow;
    }

    ref.invalidate(workoutsProvider);
    ref.invalidate(inProgressWorkoutsProvider);
    ref.invalidate(finishedWorkoutsProvider);
    return targetId;
  }
}
