import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/exercise.dart';

part 'exercises_provider.g.dart';

@Riverpod(keepAlive: true)
class ExercisesNotifier extends _$ExercisesNotifier {
  @override
  Future<List<Exercise>> build() async {
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

  Future<void> addCustomExercise(String name) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client.from('exercises').insert({
      'name': name,
      'is_predefined': false,
      'user_id': userId,
    });

    ref.invalidateSelf();
    await future;
  }
}
