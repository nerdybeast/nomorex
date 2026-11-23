import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import 'list_group.dart';

/// The one line under every load failure. Never the raw error: it names the
/// backend ("PostgrestException…") and means nothing to a lifter.
const kLoadFailureHint = 'Check your connection and try again.';

/// Shown while Riverpod is retrying a failed load on its own.
const kLoadFailureRetrying = 'Trying again…';

extension AsyncLoadFailure<T> on AsyncValue<T> {
  /// [AsyncValue.when], except that a failed load Riverpod is retrying shows
  /// [error] rather than [loading].
  ///
  /// A retry is a reload that still holds the error, and `when()` renders a
  /// reload as loading, so without this a failure shows a spinner through
  /// every backed-off retry and only appears once they've all run out. Read
  /// [AsyncValue.retrying] in the error builder to say "Trying again…".
  R whenLoaded<R>({
    required R Function(T data) data,
    required R Function(Object error, StackTrace stackTrace) error,
    required R Function() loading,
  }) {
    if (retrying && hasError) return error(this.error!, stackTrace!);
    return when(data: data, error: error, loading: loading);
  }
}

/// A screen, or a screen's whole list, that failed to load: what failed, and a
/// way to try again, centered where the content would be.
class LoadFailureView extends StatelessWidget {
  const LoadFailureView({
    super.key,
    required this.title,
    required this.onRetry,
    this.retrying = false,
    this.retryKey,
  });

  /// What failed, e.g. "Couldn't load this workout".
  final String title;
  final VoidCallback onRetry;

  /// Riverpod is already retrying; the button still skips the wait.
  final bool retrying;
  final Key? retryKey;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 4),
            Text(
              retrying ? kLoadFailureRetrying : kLoadFailureHint,
              textAlign: TextAlign.center,
              style: tokens.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: retryKey,
              style: tokens.secondaryButtonStyle.copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(160, NomorexSizes.controlHeightLg)),
              ),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// One section of a page that failed to load, as a row in the section's own
/// group, so the rest of the page carries on around it.
class LoadFailureRow extends StatelessWidget {
  const LoadFailureRow({super.key, required this.message, required this.onRetry, this.retrying = false});

  /// What failed, e.g. "Couldn't load PRs".
  final String message;
  final VoidCallback onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    return ListGroup(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error)),
                    Text(
                      retrying ? kLoadFailureRetrying : kLoadFailureHint,
                      style: tokens.bodySmall.copyWith(color: tokens.fg3),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      ],
    );
  }
}
