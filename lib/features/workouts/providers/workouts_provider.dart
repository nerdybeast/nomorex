import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout.dart';
import '../utils/workout_copier.dart';
import '../utils/workout_group_representative.dart';
import '../../auth/providers/auth_provider.dart';
import '../../community/providers/community_workouts_provider.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../../core/utils/sequential_naming.dart';
import 'finished_workouts_provider.dart';
import 'in_progress_workouts_provider.dart';
import 'workout_copy_count_provider.dart';
import 'workout_detail_provider.dart';

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
        .eq('is_archived', false)
        .order('date', ascending: false);

    return _groupRepresentatives(data as List)
      ..sort((a, b) => b.date.compareTo(a.date));
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

  /// Archives [workout] and every other session in its group: one card in
  /// this list stands for the whole group, so archiving only the
  /// representative would just surface a sibling in its place. Logged history
  /// stays visible (finishedWorkoutsProvider doesn't filter on it).
  Future<void> archiveWorkout(Workout workout) async {
    await _db
        .from('workouts')
        .update({
          'is_archived': true,
          'archived_at': DateTime.now().toIso8601String(),
        })
        .eq('user_id', _db.auth.currentUser!.id)
        .eq('workout_group_id', workout.workoutGroupId);
    _invalidateArchiveState();
    await future;
  }

  Future<void> restoreWorkout(Workout workout) async {
    await _db
        .from('workouts')
        .update({'is_archived': false, 'archived_at': null})
        .eq('user_id', _db.auth.currentUser!.id)
        .eq('workout_group_id', workout.workoutGroupId);
    _invalidateArchiveState();
    await future;
  }

  /// Hard-deletes [workout]'s whole group, history included. Only ever
  /// offered from the Archived tab, and the `is_archived` filter makes that a
  /// guarantee: an active workout can't be deleted through here.
  Future<void> deleteWorkoutPermanently(Workout workout) async {
    await _db
        .from('workouts')
        .delete()
        .eq('user_id', _db.auth.currentUser!.id)
        .eq('workout_group_id', workout.workoutGroupId)
        .eq('is_archived', true);
    // The group's finished sessions were still showing in history.
    ref.invalidate(inProgressWorkoutsProvider);
    ref.invalidate(finishedWorkoutsProvider);
    _invalidateArchiveState();
    await future;
  }

  /// Every provider whose rendered output changes when a group moves between
  /// active, archived and gone. workoutDetailProvider is invalidated as a
  /// whole family because the change spans every row in the group.
  void _invalidateArchiveState() {
    ref.invalidate(archivedWorkoutsProvider);
    ref.invalidate(communityWorkoutsProvider);
    // An archived or deleted copy no longer counts as "saved".
    ref.invalidate(workoutCopyCountProvider);
    ref.invalidate(workoutDetailProvider);
    ref.invalidateSelf();
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
      ...copyAttributionColumns(src),
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

  /// Saves a copy of another user's public workout into the viewer's own
  /// workouts and, with [start], begins a session on it — all in one
  /// transaction via the `copy_workout` RPC (exercises are mapped into the
  /// viewer's catalog by name, so this can create custom exercises). Returns
  /// the new workout's id. Errors are `PostgrestException`s whose message
  /// `copyErrorMessage()` turns into user-facing text.
  Future<String> saveCommunityWorkout(String sourceWorkoutId, {bool start = false}) async {
    final newId = await _db.rpc('copy_workout', params: {
      'p_source_workout_id': sourceWorkoutId,
      'p_today': DateTime.now().toIso8601String().split('T').first,
      'p_start': start,
    }) as String;

    ref.invalidate(exercisesProvider);
    ref.invalidate(workoutCopyCountProvider);
    if (start) ref.invalidate(inProgressWorkoutsProvider);
    ref.invalidateSelf();
    await future;
    return newId;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// Mirrors [WorkoutsNotifier] but surfaces the archived list, so a user can
/// restore a workout or delete it permanently.
@Riverpod(keepAlive: true)
class ArchivedWorkoutsNotifier extends _$ArchivedWorkoutsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<Workout>> build() async {
    ref.watch(authStateProvider);
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _db
        .from('workouts')
        .select('*, workout_exercises(*, exercises(name))')
        .eq('user_id', userId)
        .filter('program_instance_id', 'is', null)
        .eq('is_archived', true);

    return _groupRepresentatives(data as List)
      ..sort((a, b) => (b.archivedAt ?? b.updatedAt).compareTo(a.archivedAt ?? a.updatedAt));
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

/// One card per logical workout, not one per completion: groups rows by
/// workoutGroupId and keeps only the live/actionable row per group (see
/// pickGroupRepresentative). Every completion still has its own row for
/// history — this only affects what a list surfaces.
List<Workout> _groupRepresentatives(List<dynamic> rows) {
  final byGroup = <String, List<Workout>>{};
  for (final row in rows) {
    final w = Workout.fromJson(row as Map<String, dynamic>);
    byGroup.putIfAbsent(w.workoutGroupId, () => []).add(w);
  }
  return byGroup.values.map(pickGroupRepresentative).whereType<Workout>().toList();
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
