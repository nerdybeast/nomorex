import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout.dart';
import '../utils/set_builder_parser.dart';
import '../../auth/providers/auth_provider.dart';

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
        .select('*, workout_exercises(*, exercises(name), workout_sets(*))')
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
        },
    ]);
    await _refresh();
  }

  Future<void> addAbsoluteSet(String workoutExerciseId) async {
    final current = await future;
    final ex = current.exercises.firstWhere((e) => e.id == workoutExerciseId);
    await _db.from('workout_sets').insert({
      'workout_exercise_id': workoutExerciseId,
      'user_id': _userId,
      'position': ex.sets.length,
      'target_reps': 1,
      'weight_mode': 'absolute',
      'absolute_weight_kg': 0,
    });
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
}
