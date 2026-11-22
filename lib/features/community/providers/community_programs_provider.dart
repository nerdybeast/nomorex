import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../programs/models/program.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/community_page.dart';

part 'community_programs_provider.g.dart';

/// Public programs authored by *other* users, mirroring
/// [CommunityWorkoutsNotifier]. Shallow like `ProgramsNotifier`: weeks and
/// their day rows only (no exercises or sets), so the list can show week and
/// training-day counts cheaply.
@Riverpod(keepAlive: true)
class CommunityProgramsNotifier extends _$CommunityProgramsNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  /// Rows per fetch. Community grows with every lifter who shares, so it
  /// loads a page at a time instead of everything public at once.
  static const pageSize = 30;

  bool _loadingMore = false;

  @override
  Future<CommunityPage<Program>> build() async {
    ref.watch(authStateProvider);
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return const CommunityPage([], hasMore: false);
    final page = await _fetch(userId, 0);
    return CommunityPage(page, hasMore: page.length == pageSize);
  }

  /// Appends the next page. A no-op while one is already loading or when
  /// the last page came back short.
  Future<void> loadMore() async {
    final current = state.asData?.value;
    final userId = _db.auth.currentUser?.id;
    if (current == null || userId == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    try {
      final page = await _fetch(userId, current.items.length);
      state = AsyncData(CommunityPage([...current.items, ...page], hasMore: page.length == pageSize));
    } finally {
      _loadingMore = false;
    }
  }

  Future<List<Program>> _fetch(String userId, int offset) async {
    final data = await _db
        .from('programs')
        .select('*, profiles(display_name), program_weeks(*, program_days(*, program_sessions(id, program_day_id, position)))')
        .eq('is_public', true)
        // Archiving is the app's stand-in for deleting a program, so an
        // archived one must not stay browsable just because it was public.
        .eq('is_archived', false)
        .neq('user_id', userId)
        .order('created_at', ascending: false)
        // A tiebreaker, so rows sharing a created_at can't shift between pages.
        .order('id')
        .range(offset, offset + pageSize - 1);

    return (data as List)
        .map((e) => Program.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
