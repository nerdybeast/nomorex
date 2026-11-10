import 'package:intl/intl.dart';

import '../models/ai_import_limits.dart';

/// Why an import can't start, for a refusal from `ai_import_check()` or from
/// the `startAiImport` flow (whose error message is the bare reason code).
/// #88 may reword these at launch; the reasons themselves are fixed.
String importRefusalMessage(String? reason, {DateTime? resetsAt, int? dailyLimit, int? monthlyLimit}) {
  final local = resetsAt?.toLocal();
  return switch (reason) {
    'imports_disabled' => 'Imports are switched off right now. Try again later.',
    'consent_required' => 'Accept the AI import notice before uploading files.',
    'active_import' => 'An import is already running. Wait for it to finish, then try again.',
    'daily_limit' => [
      dailyLimit == null ? "You've reached today's import limit." : "You've used all $dailyLimit of today's imports.",
      if (local != null) 'You can import again at ${DateFormat.jm().format(local)}.',
    ].join(' '),
    'monthly_limit' => [
      monthlyLimit == null
          ? "You've reached this month's import limit."
          : "You've used all $monthlyLimit of this month's imports.",
      if (local != null) 'You can import again on ${DateFormat.MMMd().format(local)}.',
    ].join(' '),
    'failure_limit' => [
      'Too many imports have failed today.',
      if (local != null) 'Try again at ${DateFormat.jm().format(local)}.',
    ].join(' '),
    'import_closed' => 'That import has already finished.',
    'invalid_input' => "Those files couldn't be imported.",
    _ => "Imports aren't available right now. Try again in a moment.",
  };
}

String importCheckMessage(AiImportCheck check) => importRefusalMessage(
  check.reason,
  resetsAt: check.resetsAt,
  dailyLimit: check.dailyLimit,
  monthlyLimit: check.monthlyLimit,
);
