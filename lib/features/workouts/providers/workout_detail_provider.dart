import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/set_type.dart';
import '../models/workout.dart';
import '../utils/parsed_set.dart';
import '../../auth/providers/auth_provider.dart';
import '../../programs/providers/finished_program_instances_provider.dart';
import '../../programs/providers/program_instance_detail_provider.dart';
import '../../programs/providers/program_instances_list_provider.dart';
import 'finished_workouts_provider.dart';
import 'in_progress_workouts_provider.dart';
import 'workouts_provider.dart';
import '../../analytics/analytics.dart';
import '../../analytics/providers/analytics_provider.dart';

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
    final nextPos = current.exercises.isEmpty
        ? 0
        : current.exercises.map((e) => e.position).reduce((a, b) => a > b ? a : b) + 1;
    await _db.from('workout_exercises').insert({
      'workout_id': workoutId,
      'user_id': _userId,
      'exercise_id': exerciseId,
      'position': nextPos,
    });
    // The Workouts list renders an exercise count off its own cached copy of
    // this workout, so a changed exercise list has to invalidate it too —
    // otherwise a workout built right after creation keeps showing
    // "0 exercises" until the list is refetched some other way.
    ref.invalidate(workoutsProvider);
    await _refresh();
  }

  Future<void> removeExercise(String workoutExerciseId) async {
    await _db.from('workout_exercises').delete().eq('id', workoutExerciseId);
    ref.invalidate(workoutsProvider);
    await _refresh();
  }

  Future<void> updateExerciseNotes(String workoutExerciseId, String? notes) async {
    await _db
        .from('workout_exercises')
        .update({'notes': (notes != null && notes.isEmpty) ? null : notes})
        .eq('id', workoutExerciseId);
    await _refresh();
  }

  /// Reassigns the position values `workout_exercises` already held by
  /// [orderedExerciseIds] in the new order. `workout_exercises.position` has
  /// no unique constraint, so a single sequential pass is safe here (unlike
  /// ProgramDetailNotifier.reorderWeeks/reorderDays, which need a two-phase
  /// negative-then-final trick to dodge a unique constraint).
  Future<void> reorderExercises(List<String> orderedExerciseIds) async {
    final current = await future;
    final positions = (orderedExerciseIds
            .map((id) => current.exercises.firstWhere((e) => e.id == id).position)
            .toList()
          ..sort());
    for (var i = 0; i < orderedExerciseIds.length; i++) {
      await _db
          .from('workout_exercises')
          .update({'position': positions[i]}).eq('id', orderedExerciseIds[i]);
    }
    await _refresh();
  }

  /// Same idea for a single exercise's sets.
  Future<void> reorderSets(String workoutExerciseId, List<String> orderedSetIds) async {
    final current = await future;
    final ex = current.exercises.firstWhere((e) => e.id == workoutExerciseId);
    final positions = (orderedSetIds
            .map((id) => ex.sets.firstWhere((s) => s.id == id).position)
            .toList()
          ..sort());
    for (var i = 0; i < orderedSetIds.length; i++) {
      await _db.from('workout_sets').update({'position': positions[i]}).eq('id', orderedSetIds[i]);
    }
    await _refresh();
  }

  /// Moves just-added [newIds], all of [type], to the end of their type's run
  /// (warm-ups before working sets before cool-downs), so a warm-up added
  /// after the working sets lands above them instead of at the bottom. Within
  /// a type, order stays the lifter's. A no-op when they're already there.
  Future<void> _placeByType(String exerciseId, List<String> newIds, SetType type) async {
    if (newIds.isEmpty) return;
    final current = await future;
    final ex = current.exercises.firstWhere((e) => e.id == exerciseId);
    final sorted = [...ex.sets]..sort((a, b) => a.position.compareTo(b.position));
    final order = placeByType(sorted, idOf: (s) => s.id, typeOf: (s) => s.setType, newIds: newIds, type: type);
    if (const ListEquality<String>().equals(order, [for (final s in sorted) s.id])) return;
    await reorderSets(exerciseId, order);
  }

  Future<void> addPercentageSets(
      String workoutExerciseId, List<ParsedSet> parsed) async {
    if (parsed.isEmpty) return;
    final current = await future;
    final ex = current.exercises.firstWhere((e) => e.id == workoutExerciseId);
    var pos = ex.sets.isEmpty
        ? 0
        : ex.sets.map((s) => s.position).reduce((a, b) => a > b ? a : b) + 1;
    final inserted = await _db.from('workout_sets').insert([
      for (final p in parsed)
        {
          'workout_exercise_id': workoutExerciseId,
          'user_id': _userId,
          'position': pos++,
          'target_reps': p.targetReps,
          if (p.targetRepsMax != null) 'target_reps_max': p.targetRepsMax,
          'weight_mode': 'percentage',
          'percentage': p.percentage,
          'percentage_max': ?p.percentageMax,
          'basis_exercise_id': p.basisExerciseId,
          'rpe_min': ?p.rpeMin,
          'rpe_max': ?p.rpeMax,
          'set_type': p.setType.dbValue,
        },
    ]).select('id');
    await _refresh();
    await _placeByType(workoutExerciseId, [for (final row in inserted) row['id'] as String], parsed.first.setType);
  }

  Future<void> addAbsoluteSets(String workoutExerciseId, AbsoluteSetBatch batch) async {
    if (batch.sets <= 0) return;
    final current = await future;
    final ex = current.exercises.firstWhere((e) => e.id == workoutExerciseId);
    var pos = ex.sets.isEmpty
        ? 0
        : ex.sets.map((s) => s.position).reduce((a, b) => a > b ? a : b) + 1;
    final inserted = await _db.from('workout_sets').insert([
      for (var i = 0; i < batch.sets; i++)
        {
          'workout_exercise_id': workoutExerciseId,
          'user_id': _userId,
          'position': pos++,
          'target_reps': batch.reps,
          'target_reps_max': ?batch.repsMax,
          'weight_mode': batch.weightKg == null ? 'open' : 'absolute',
          'absolute_weight_kg': batch.weightKg,
          'rpe_min': ?batch.rpeMin,
          'rpe_max': ?batch.rpeMax,
          'set_type': batch.setType.dbValue,
        },
    ]).select('id');
    await _refresh();
    await _placeByType(workoutExerciseId, [for (final row in inserted) row['id'] as String], batch.setType);
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

  /// Records what the lifter actually did on a set in one update: the reps,
  /// the RPE and, on an open-load set (the only kind without a prescribed
  /// load), the weight used. Null clears a value. Logging-only: never copied
  /// when the workout is duplicated or shared. [complete] also ticks the set,
  /// since logging it means it was done.
  Future<void> logSet(
    String setId, {
    required int? reps,
    required double? rpe,
    double? weightKg,
    bool complete = true,
  }) async {
    await _db.from('workout_sets').update({
      'actual_reps': reps,
      'actual_rpe': rpe,
      'actual_weight_kg': weightKg,
      if (complete) 'completed': true,
    }).eq('id', setId);
    await _refresh();
  }

  /// Replaces a run of identical consecutive sets ([setIds], all of one
  /// exercise) with [count] sets of [prescription], in the same place, in one
  /// transaction. A count of 0 removes the group. [prescription] uses the
  /// column names (`target_reps`, `weight_mode`, `absolute_weight_kg` in kg,
  /// `set_type`, …); see `replace_workout_set_group`.
  Future<void> replaceSetGroup(List<String> setIds, int count, Map<String, Object?> prescription) async {
    await _db.rpc('replace_workout_set_group', params: {
      'p_set_ids': setIds,
      'p_count': count,
      'p_set': prescription,
    });
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
    ref.read(analyticsProvider).logEvent(AnalyticsEvents.workoutStarted, {'method': 'start'});
    _invalidateStatusLists();
    await _refresh();
  }

  Future<void> pauseWorkout() async {
    await _db.rpc('pause_workout_session', params: {'p_workout_id': workoutId});
    _invalidateStatusLists();
    await _refresh();
  }

  Future<void> resumeWorkout() async {
    await _db.rpc('resume_workout_session', params: {'p_workout_id': workoutId});
    _invalidateStatusLists();
    await _refresh();
  }

  /// A session status change moves the label the dashboard's in-progress
  /// card and the Workouts list both render from their own cached rows.
  void _invalidateStatusLists() {
    ref.invalidate(inProgressWorkoutsProvider);
    ref.invalidate(workoutsProvider);
  }

  /// Finishes the session and, for a standalone workout, eagerly creates the
  /// next not-started instance of its group so the Workouts list always has a
  /// live row to show instead of this now-frozen completion. Both happen in
  /// one transaction in the `finish_workout` RPC, which skips the next
  /// instance for program-materialized days and when a live sibling exists.
  Future<void> finishWorkout({String? sessionNotes}) async {
    final current = await future;
    await _db.rpc('finish_workout', params: {
      'p_workout_id': workoutId,
      'p_session_notes': sessionNotes,
      'p_today': DateTime.now().toIso8601String().split('T').first,
    });
    ref.read(analyticsProvider).logEvent(AnalyticsEvents.workoutFinished, {
      'from_program': current.programInstanceId != null ? 1 : 0,
    });

    ref.invalidate(workoutsProvider);
    ref.invalidate(inProgressWorkoutsProvider);
    ref.invalidate(finishedWorkoutsProvider);
    // A finished program-day workout moves its run's "workouts / weeks
    // completed" counts, which the dashboard, Programs list and Program
    // history all render from these providers.
    if (current.programInstanceId != null) {
      ref.invalidate(currentProgramInstancesProvider);
      ref.invalidate(finishedProgramInstancesProvider);
      ref.invalidate(programInstanceDetailProvider(current.programInstanceId!));
    }
    await _refresh();
  }

  Future<void> discardSession() async {
    await _db.rpc('discard_workout_session', params: {'p_workout_id': workoutId});
    _invalidateStatusLists();
    await _refresh();
  }

  /// Starts another instance of this workout's group via the `repeat_workout`
  /// RPC: it reuses the not-started sibling if there is one (finishing a
  /// workout eagerly creates it, see finishWorkout()), otherwise creates and
  /// copies a new one, then starts it, all in one transaction. Throws a
  /// [StateError] instead of creating a second in-progress instance of the
  /// same logical workout: refused up front by the RPC, and backed by the
  /// DB's partial unique index (23505) as a race guard.
  Future<String> repeatWorkout() async {
    final String targetId;
    try {
      targetId = await _db.rpc('repeat_workout', params: {
        'p_workout_id': workoutId,
        'p_today': DateTime.now().toIso8601String().split('T').first,
      }) as String;
    } on PostgrestException catch (e) {
      if (e.code == '23505' || e.message.startsWith('already_in_progress:')) {
        throw StateError('This workout is already in progress.');
      }
      rethrow;
    }
    ref.read(analyticsProvider).logEvent(AnalyticsEvents.workoutStarted, {'method': 'repeat'});

    ref.invalidate(workoutsProvider);
    ref.invalidate(inProgressWorkoutsProvider);
    ref.invalidate(finishedWorkoutsProvider);
    return targetId;
  }
}
