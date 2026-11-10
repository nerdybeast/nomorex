import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_provider.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../programs/providers/programs_provider.dart';
import '../../workouts/providers/workouts_provider.dart';
import '../models/ai_import_result.dart';
import 'ai_import_intake_provider.dart';
import 'ai_import_jobs_provider.dart';

part 'ai_import_review_provider.g.dart';

/// One import job as the review screen needs it: its status and, once ready,
/// what was read.
class AiImportReview {
  const AiImportReview({
    required this.jobId,
    required this.importId,
    required this.status,
    this.type,
    this.result,
    this.acceptedWorkoutId,
    this.acceptedProgramId,
  });

  factory AiImportReview.fromJson(Map<String, dynamic> json) {
    // A one-to-one embed comes back as an object, but tolerate a list.
    final embedded = json['ai_import_results'];
    final row = embedded is List ? embedded.firstOrNull : embedded;
    final payload = row is Map ? row['payload'] : null;
    return AiImportReview(
      jobId: json['id'] as String,
      importId: json['import_id'] as String,
      status: json['status'] as String,
      type: (json['requested_type'] ?? json['detected_type']) as String?,
      result: payload is Map ? AiImportResult.fromJson(Map<String, dynamic>.from(payload)) : null,
      acceptedWorkoutId: json['accepted_workout_id'] as String?,
      acceptedProgramId: json['accepted_program_id'] as String?,
    );
  }

  static const columns =
      'id, import_id, status, requested_type, detected_type, accepted_workout_id, accepted_program_id, '
      'ai_import_results(payload)';

  final String jobId;
  final String importId;
  final String status;
  final String? type;

  /// Present only while the job is `ready`; the result is deleted once the
  /// job is accepted, discarded or replaced.
  final AiImportResult? result;
  final String? acceptedWorkoutId;
  final String? acceptedProgramId;
}

/// Where an accepted import was saved. Exactly one is set.
typedef AcceptedImport = ({String? workoutId, String? programId});

/// One import's review: the job and its result, plus the three ways out of a
/// review (accept, re-run as the other type, discard). Null when the job
/// doesn't exist or isn't the signed-in user's.
@riverpod
class AiImportReviewNotifier extends _$AiImportReviewNotifier {
  @override
  Future<AiImportReview?> build(String jobId) async {
    final user = ref.watch(currentAuthUserProvider);
    if (user == null) return null;
    return fetchReview(jobId);
  }

  /// Saves the reviewed import and returns what it became. Safe to retry:
  /// accepting an already accepted job returns the same item.
  Future<AcceptedImport> accept(Map<String, dynamic> reviewed) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final saved = await acceptImport(jobId, reviewed, today);
    // Accept can create custom exercises as well as the item itself.
    ref.invalidate(workoutsProvider);
    ref.invalidate(programsProvider);
    ref.invalidate(exercisesProvider);
    ref.invalidate(aiImportJobsProvider);
    return saved;
  }

  /// Reads the same files again as [type]. Uses one of the user's imports,
  /// and replaces this job, whose result is deleted. Returns the new job ID.
  Future<String> rerunAs(String importId, String type) async {
    final newJobId = await startImport(importId, type);
    ref.invalidate(aiImportJobsProvider);
    return newJobId;
  }

  Future<void> discard() => ref.read(aiImportJobsProvider.notifier).discard(jobId);

  // Network calls, split out so tests can override them.

  Future<AiImportReview?> fetchReview(String jobId) async {
    final row = await Supabase.instance.client
        .from('ai_import_jobs')
        .select(AiImportReview.columns)
        .eq('id', jobId)
        .maybeSingle();
    return row == null ? null : AiImportReview.fromJson(row);
  }

  Future<AcceptedImport> acceptImport(String jobId, Map<String, dynamic> reviewed, String today) async {
    final result = await Supabase.instance.client.rpc(
      'ai_import_accept',
      params: {'p_job_id': jobId, 'p_reviewed': reviewed, 'p_today': today},
    );
    final map = result as Map;
    return (workoutId: map['workout_id'] as String?, programId: map['program_id'] as String?);
  }

  Future<String> startImport(String importId, String type) => callStartAiImport(importId, requestedType: type);
}
