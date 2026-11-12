import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/providers/auth_provider.dart';

part 'recent_exercises_provider.g.dart';

/// How many lifts the exercise picker's "Recent" section lists.
const kRecentExerciseCount = 8;

/// The ids of the exercises the user most recently added to a workout or a
/// program day, newest first and without repeats.
///
/// Auto-disposed rather than `keepAlive`: only the exercise picker watches
/// it, and re-reading each time the picker opens keeps it current without
/// every add-exercise path having to invalidate it.
@riverpod
Future<List<String>> recentExerciseIds(Ref ref) async {
  ref.watch(authStateProvider);
  final db = Supabase.instance.client;
  final userId = db.auth.currentUser?.id;
  if (userId == null) return const [];

  // Enough rows that a workout repeating one lift a few times still leaves
  // [kRecentExerciseCount] distinct ones.
  const window = 60;
  final results = await Future.wait([
    db
        .from('workout_exercises')
        .select('exercise_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(window),
    db
        .from('program_exercises')
        .select('exercise_id, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(window),
  ]);
  return mostRecentExerciseIds([
    for (final rows in results)
      for (final row in rows)
        (
          exerciseId: row['exercise_id'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
        ),
  ]);
}

/// Distinct exercise ids from [rows], newest first, capped at [limit].
List<String> mostRecentExerciseIds(
  List<({String exerciseId, DateTime createdAt})> rows, {
  int limit = kRecentExerciseCount,
}) {
  final sorted = [...rows]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final seen = <String>{};
  for (final row in sorted) {
    if (seen.add(row.exerciseId) && seen.length == limit) break;
  }
  return seen.toList();
}
