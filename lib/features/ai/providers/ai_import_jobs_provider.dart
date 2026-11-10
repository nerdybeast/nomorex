import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../models/ai_import_job.dart';
import 'ai_import_intake_provider.dart';

part 'ai_import_jobs_provider.g.dart';

/// The signed-in user's open imports: processing, ready to review, or failed
/// and not yet dismissed. Newest first.
///
/// The job row is the only source of truth. Realtime ([aiImportJobWatchProvider])
/// and app resume only prompt a re-read of this provider; neither carries
/// state, because events missed while disconnected are never replayed.
///
/// Watches [currentAuthUserProvider] (which watches `authStateProvider`), so a
/// sign-out empties it and nothing crosses accounts.
@Riverpod(keepAlive: true)
class AiImportJobsNotifier extends _$AiImportJobsNotifier {
  @override
  Future<List<AiImportJob>> build() async {
    final user = ref.watch(currentAuthUserProvider);
    if (user == null) return const [];
    return fetchJobs(user.id);
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Dismisses a ready or failed import and deletes its uploaded files.
  /// [importId] defaults to the listed job's.
  Future<void> discard(String jobId, {String? importId}) async {
    importId ??= state.value?.where((j) => j.id == jobId).firstOrNull?.importId;
    await discardJob(jobId);
    if (importId != null) await removeImportFiles(importId);
    ref.invalidateSelf();
    await future;
  }

  /// Deletes an accepted or discarded import's uploaded files, under the
  /// user's session. Never throws: whatever is left, the daily cleanup
  /// (`ai-import-cleanup`) deletes on its next run.
  Future<void> removeImportFiles(String importId) async {
    final userId = ref.read(currentAuthUserProvider)?.id;
    if (userId == null) return;
    try {
      await deleteImportFiles('$userId/$importId');
    } catch (e) {
      debugPrint('[ai_import] removing files failed, left for the cleanup: $e');
    }
  }

  // Network calls, split out so tests can override them.

  Future<List<AiImportJob>> fetchJobs(String userId) async {
    final rows = await Supabase.instance.client
        .from('ai_import_jobs')
        .select(AiImportJob.columns)
        .eq('user_id', userId)
        .inFilter('status', const ['processing', 'ready', 'failed'])
        .order('started_at', ascending: false)
        .limit(20);
    return [for (final row in rows) AiImportJob.fromJson(row)];
  }

  Future<void> discardJob(String jobId) =>
      Supabase.instance.client.rpc('ai_import_discard', params: {'p_job_id': jobId});

  Future<void> deleteImportFiles(String folder) async {
    final storage = Supabase.instance.client.storage.from('ai-imports');
    final files = await storage.list(path: folder);
    if (files.isEmpty) return;
    await storage.remove([for (final f in files) '$folder/${f.name}']);
  }
}

/// Subscribes to changes to [userId]'s import jobs, calling [onChange] for
/// each change and each time the channel (re)connects. Returns a function
/// that unsubscribes.
typedef AiImportJobSubscriber = void Function() Function(String userId, void Function() onChange);

/// The Realtime subscription, as a provider so tests can replace it.
@Riverpod(keepAlive: true)
AiImportJobSubscriber aiImportJobSubscriber(Ref ref) => (userId, onChange) {
  final client = Supabase.instance.client;
  final channel = client
      .channel('ai-import-jobs:$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'ai_import_jobs',
        // RLS also limits events to the user's own rows; the filter
        // keeps the server from evaluating everyone else's.
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
        callback: (_) => onChange(),
      )
      .subscribe((status, _) {
        // Re-read on every (re)connect: a change made while disconnected,
        // or between the last read and this subscription, isn't replayed.
        if (status == RealtimeSubscribeStatus.subscribed) onChange();
      });
  return () => client.removeChannel(channel);
};

/// The earliest start among processing jobs, or null if none is processing.
DateTime? _processingSince(List<AiImportJob>? jobs) {
  DateTime? since;
  for (final job in jobs ?? const <AiImportJob>[]) {
    if (job.status == 'processing' && (since == null || job.startedAt.isBefore(since))) since = job.startedAt;
  }
  return since;
}

/// Keeps [aiImportJobsProvider] current while an import is processing.
///
/// Subscribes to Realtime only while there's a live job to hear about, so a
/// user who never imports never holds a socket open. Also sets a timer for
/// the job's deadline: past it the job shows as failed, whether or not the
/// server has said anything. Watched for the app's lifetime from
/// `AiImportJobAlerts`.
@Riverpod(keepAlive: true)
void aiImportJobWatch(Ref ref) {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null) return;
  // A select, so this rebuilds (and resubscribes) only when the set of
  // processing jobs changes, not on every re-read.
  final since = ref.watch(aiImportJobsProvider.select((jobs) => _processingSince(jobs.value)));
  if (since == null) return;
  final maxJobSeconds = ref.watch(aiImportLimitsProvider.select((l) => l.value?.maxJobSeconds));
  if (maxJobSeconds == null) return; // Rebuilds once the limits arrive.

  final deadline = since.add(Duration(seconds: maxJobSeconds));
  final untilDeadline = deadline.difference(DateTime.now());
  // Already dead: shown as failed, nothing left to wait for.
  if (untilDeadline <= Duration.zero) return;

  void reread() => ref.invalidate(aiImportJobsProvider);
  final unsubscribe = ref.read(aiImportJobSubscriberProvider)(user.id, reread);
  final timer = Timer(untilDeadline + const Duration(seconds: 1), () {
    // Re-render the job as failed, and rebuild this watcher, which then
    // finds the job past its deadline and drops the subscription.
    reread();
    ref.invalidateSelf();
  });
  ref.onDispose(() {
    timer.cancel();
    unsubscribe();
  });
}
