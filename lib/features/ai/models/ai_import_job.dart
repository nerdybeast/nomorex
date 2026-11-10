/// What the app shows for an import job. Differs from the stored status in
/// one way: a job still `processing` past the longest possible run is shown
/// as failed, because its worker is dead even if the sweep hasn't marked it.
enum AiImportJobState { processing, ready, failed }

/// One row of `ai_import_jobs`: a single AI run over an import's files.
/// The extracted result lives in `ai_import_results`, read only on review.
class AiImportJob {
  const AiImportJob({
    required this.id,
    required this.importId,
    required this.status,
    required this.startedAt,
    this.requestedType,
    this.detectedType,
    this.failureCode,
    this.finishedAt,
  });

  factory AiImportJob.fromJson(Map<String, dynamic> json) => AiImportJob(
    id: json['id'] as String,
    importId: json['import_id'] as String,
    status: json['status'] as String,
    startedAt: DateTime.parse(json['started_at'] as String),
    requestedType: json['requested_type'] as String?,
    detectedType: json['detected_type'] as String?,
    failureCode: json['failure_code'] as String?,
    finishedAt: json['finished_at'] == null ? null : DateTime.parse(json['finished_at'] as String),
  );

  /// The columns [AiImportJob.fromJson] reads.
  static const columns = 'id, import_id, status, started_at, requested_type, detected_type, failure_code, finished_at';

  final String id;
  final String importId;

  /// `processing`, `ready`, `failed`, `accepted`, `discarded` or `replaced`.
  final String status;
  final DateTime startedAt;
  final String? requestedType;
  final String? detectedType;
  final String? failureCode;
  final DateTime? finishedAt;

  /// `workout` or `program`: what the user asked for, else what was found.
  String? get type => requestedType ?? detectedType;

  /// When a processing job is treated as dead.
  DateTime deadline(int maxJobSeconds) => startedAt.add(Duration(seconds: maxJobSeconds));

  /// Still processing, but past the longest possible run.
  bool isStale(DateTime now, int maxJobSeconds) => status == 'processing' && !now.isBefore(deadline(maxJobSeconds));

  /// The state to show, or null for a job that's finished with (accepted,
  /// discarded or replaced) and shouldn't be shown at all.
  AiImportJobState? state(DateTime now, int maxJobSeconds) => switch (status) {
    'processing' => isStale(now, maxJobSeconds) ? AiImportJobState.failed : AiImportJobState.processing,
    'ready' => AiImportJobState.ready,
    'failed' => AiImportJobState.failed,
    _ => null,
  };

  /// Only `ready` and `failed` jobs can be discarded; a stale job is still
  /// `processing` on the server until the sweep marks it.
  bool get canDiscard => status == 'ready' || status == 'failed';

  /// Why a failed job failed, in the user's terms.
  String failureMessage(DateTime now, int maxJobSeconds) {
    if (isStale(now, maxJobSeconds)) return 'The import stopped before it finished. Try again.';
    return switch (failureCode) {
      'no_workout_found' => "We couldn't find a workout or program in those files.",
      'invalid_file' => "One of the files wasn't a JPEG, PNG, WebP or PDF, or was over the size limit.",
      'unreadable_file' => "The files couldn't be read. A password-protected PDF can't be imported.",
      'timeout' => 'Reading the files took too long. Try fewer pages.',
      'model_error' => 'The AI service was unavailable. Try again later.',
      'abandoned' => 'The import stopped before it finished. Try again.',
      _ => 'Something went wrong reading the import. Try again.',
    };
  }
}
