/// The file caps from the single `ai_import_limits` row. The server enforces
/// them; the app reads them so it can refuse a file before uploading it and
/// name the limit in the message.
class AiImportLimits {
  const AiImportLimits({
    required this.maxImages,
    required this.maxPdfPages,
    required this.maxImageBytes,
    required this.maxPdfBytes,
    this.maxJobSeconds = 180,
  });

  factory AiImportLimits.fromJson(Map<String, dynamic> json) => AiImportLimits(
    maxImages: (json['max_images'] as num).toInt(),
    maxPdfPages: (json['max_pdf_pages'] as num).toInt(),
    maxImageBytes: (json['max_image_bytes'] as num).toInt(),
    maxPdfBytes: (json['max_pdf_bytes'] as num).toInt(),
    maxJobSeconds: (json['max_job_seconds'] as num?)?.toInt() ?? 180,
  );

  final int maxImages;
  final int maxPdfPages;
  final int maxImageBytes;
  final int maxPdfBytes;

  /// How long a job can possibly run. A job still processing after this is
  /// dead (the worker was killed), even before the cleanup sweep marks it.
  final int maxJobSeconds;
}

/// The result of `ai_import_check()`: whether this user may start an import
/// now, and if not, why and when that changes.
class AiImportCheck {
  const AiImportCheck({required this.allowed, this.reason, this.resetsAt, this.dailyLimit, this.monthlyLimit});

  factory AiImportCheck.fromJson(Map<String, dynamic> json) => AiImportCheck(
    allowed: json['allowed'] == true,
    reason: json['reason'] as String?,
    resetsAt: json['resets_at'] == null ? null : DateTime.parse(json['resets_at'] as String),
    dailyLimit: (json['daily_limit'] as num?)?.toInt(),
    monthlyLimit: (json['monthly_limit'] as num?)?.toInt(),
  );

  final bool allowed;

  /// `imports_disabled`, `consent_required`, `active_import`, `daily_limit`,
  /// `monthly_limit` or `failure_limit`.
  final String? reason;
  final DateTime? resetsAt;
  final int? dailyLimit;
  final int? monthlyLimit;
}
