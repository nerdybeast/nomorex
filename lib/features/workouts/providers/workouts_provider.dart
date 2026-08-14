import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout.dart';
import '../utils/workout_copier.dart';
import '../utils/workout_group_representative.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/sequential_naming.dart';

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
    // Excludes workouts materialized from a program (program_instance_id set) —
    // those surface via the program instance's own screen, not this list.
    final data = await _db
        .from('workouts')
        .select('*, workout_exercises(*, exercises(name))')
        .eq('user_id', userId)
        .filter('program_instance_id', 'is', null)
        .order('date', ascending: false);

    final all = (data as List)
        .map((e) => Workout.fromJson(e as Map<String, dynamic>))
        .toList();

    // One card per logical workout, not one per completion: group by
    // workoutGroupId and keep only the live/actionable row per group (see
    // pickGroupRepresentative). Every completion still has its own row for
    // history — this only affects what this list surfaces.
    final byGroup = <String, List<Workout>>{};
    for (final w in all) {
      byGroup.putIfAbsent(w.workoutGroupId, () => []).add(w);
    }
    final representatives = byGroup.values
        .map(pickGroupRepresentative)
        .whereType<Workout>()
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return representatives;
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

    await copyWorkoutContents(
      _db,
      userId: userId,
      sourceExercises: src.exercises,
      targetWorkoutId: newWorkoutId,
    );

    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// "Workout N" where N is one past the highest numbered workout title the
/// user has, across all their workouts (including ones materialized from a
/// program), so a freed-up number can't collide with an existing title.
@riverpod
Future<String> nextWorkoutName(Ref ref) async {
  ref.watch(authStateProvider);
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return 'Workout 1';

  final data = await Supabase.instance.client
      .from('workouts')
      .select('title')
      .eq('user_id', userId);

  final names = (data as List).map((e) => e['title'] as String);
  return nextSequentialName(names, 'Workout');
}
