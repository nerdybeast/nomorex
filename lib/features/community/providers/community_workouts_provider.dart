import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../workouts/models/workout.dart';
import '../../auth/providers/auth_provider.dart';

part 'community_workouts_provider.g.dart';

@Riverpod(keepAlive: true)
class CommunityWorkoutsNotifier extends _$CommunityWorkoutsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  /// Rows per fetch. Community grows with every lifter who shares, so it
  /// loads a page at a time instead of everything public at once.
  static const pageSize = 30;

  bool _hasMore = false;
  bool _loadingMore = false;

  /// Whether another page may exist past what's loaded.
  bool get hasMore => _hasMore;

  @override
  Future<List<Workout>> build() async {
    ref.watch(authStateProvider);
    _hasMore = false;
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return [];
    final page = await _fetch(userId, 0);
    _hasMore = page.length == pageSize;
    return page;
  }

  /// Appends the next page. A no-op while one is already loading or when
  /// the last page came back short.
  Future<void> loadMore() async {
    final current = state.asData?.value;
    final userId = _db.auth.currentUser?.id;
    if (current == null || userId == null || !_hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await _fetch(userId, current.length);
      _hasMore = page.length == pageSize;
      state = AsyncData([...current, ...page]);
    } finally {
      _loadingMore = false;
    }
  }

  Future<List<Workout>> _fetch(String userId, int offset) async {
    final data = await _db
        .from('workouts')
        .select('*, profiles(display_name), workout_exercises(*, exercises(name))')
        .eq('is_public', true)
        // Archiving is a workout's step before deletion, so an archived one
        // must not stay browsable just because it was public.
        .eq('is_archived', false)
        .neq('user_id', userId)
        .order('date', ascending: false)
        // A tiebreaker, so rows sharing a date can't shift between pages.
        .order('id')
        .range(offset, offset + pageSize - 1);

    return (data as List)
        .map((e) => Workout.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
