import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout.dart';
import '../../auth/providers/auth_provider.dart';

part 'workouts_provider.g.dart';

@Riverpod(keepAlive: true)
class WorkoutsNotifier extends _$WorkoutsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<Workout>> build() async {
    ref.watch(authStateProvider);
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    // Shallow: workout + its exercises (with names) for counts/summary.
    final data = await _db
        .from('workouts')
        .select('*, workout_exercises(*, exercises(name))')
        .eq('user_id', userId)
        .order('date', ascending: false);

    return (data as List)
        .map((e) => Workout.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> createWorkout({
    String title = 'New Workout',
    String? notes,
    bool isPublic = false,
  }) async {
    final userId = _db.auth.currentUser!.id;
    final row = await _db.from('workouts').insert({
      'user_id': userId,
      'title': title,
      'date': DateTime.now().toIso8601String().split('T').first,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      'is_public': isPublic,
    }).select('id').single();

    ref.invalidateSelf();
    await future;
    return row['id'] as String;
  }

  Future<void> deleteWorkout(String id) async {
    await _db.from('workouts').delete().eq('id', id);
    ref.invalidateSelf();
    await future;
  }

  /// Deep-copies a workout (and its exercises + sets) to a new workout dated
  /// today. Copied sets reset completed/actual fields.
  Future<void> duplicateWorkout(String id) async {
    final userId = _db.auth.currentUser!.id;
    final source = await _db
        .from('workouts')
        .select('*, workout_exercises(*, workout_sets(*))')
        .eq('id', id)
        .single();
    final src = Workout.fromJson(source);

    final newWorkout = await _db.from('workouts').insert({
      'user_id': userId,
      'title': '${src.title} (copy)',
      'date': DateTime.now().toIso8601String().split('T').first,
      if (src.notes != null) 'notes': src.notes,
    }).select('id').single();
    final newWorkoutId = newWorkout['id'] as String;

    for (final ex in src.exercises) {
      final newEx = await _db.from('workout_exercises').insert({
        'workout_id': newWorkoutId,
        'user_id': userId,
        'exercise_id': ex.exerciseId,
        'position': ex.position,
        if (ex.notes != null) 'notes': ex.notes,
      }).select('id').single();
      final newExId = newEx['id'] as String;

      if (ex.sets.isEmpty) continue;
      await _db.from('workout_sets').insert([
        for (final s in ex.sets)
          {
            'workout_exercise_id': newExId,
            'user_id': userId,
            'position': s.position,
            'target_reps': s.targetReps,
            'weight_mode': s.weightMode,
            'percentage': s.percentage,
            'absolute_weight_kg': s.absoluteWeightKg,
            'basis_exercise_id': s.basisExerciseId,
            'note': s.note,
          },
      ]);
    }

    ref.invalidateSelf();
    await future;
  }
}
