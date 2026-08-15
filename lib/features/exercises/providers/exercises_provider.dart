import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise.dart';
import '../../../features/auth/providers/auth_provider.dart';

part 'exercises_provider.g.dart';

@Riverpod(keepAlive: true)
class ExercisesNotifier extends _$ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async {
    // Rebuild whenever auth state changes (prevents cross-user data leaks)
    ref.watch(authStateProvider);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await Supabase.instance.client
        .from('exercises')
        .select()
        .or('is_predefined.eq.true,user_id.eq.$userId')
        .order('name');

    return (data as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Exercise> addCustomExercise(String name) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final response = await Supabase.instance.client
        .from('exercises')
        .insert({
          'name': name,
          'is_predefined': false,
          'user_id': userId,
        })
        .select()
        .single();

    ref.invalidateSelf();
    await future;

    return Exercise.fromJson(response);
  }

  /// The viewer's own exercise named [name] (case-insensitive), creating a
  /// custom one if they don't already have it. Lets a viewer record a PR
  /// against a lift that so far only exists in another user's catalog — e.g.
  /// tapping "set PR" on a public workout built around the owner's custom
  /// exercise, whose id means nothing to the viewer.
  ///
  /// `exercises.name` has no unique constraint, so the dedupe here is
  /// best-effort by design: it stops repeat taps piling up duplicates without
  /// pretending to be a database-level guarantee.
  Future<Exercise> ensureExerciseByName(String name) async {
    final trimmed = name.trim();
    final existing = await future;
    for (final e in existing) {
      if (e.name.toLowerCase() == trimmed.toLowerCase()) return e;
    }
    return addCustomExercise(trimmed);
  }
}
