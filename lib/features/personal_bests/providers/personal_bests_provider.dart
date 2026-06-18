import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/personal_best.dart';

part 'personal_bests_provider.g.dart';

@Riverpod(keepAlive: true)
class PersonalBestsNotifier extends _$PersonalBestsNotifier {
  @override
  Future<List<PersonalBest>> build() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await Supabase.instance.client
        .from('personal_bests')
        .select('*, exercises(id, name)')
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (data as List)
        .map((e) => PersonalBest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> addPr({
    required String exerciseId,
    required double weightKg,
    required int reps,
    required DateTime date,
    String? notes,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    await Supabase.instance.client.from('personal_bests').insert({
      'user_id': userId,
      'exercise_id': exerciseId,
      'weight_kg': weightKg,
      'reps': reps,
      'date': date.toIso8601String().split('T').first, // date only
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });

    ref.invalidateSelf();
    await future;
  }
}
