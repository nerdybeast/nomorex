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
}
