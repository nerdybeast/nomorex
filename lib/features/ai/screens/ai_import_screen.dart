import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/list_group.dart';
import '../models/ai_import_limits.dart';
import '../providers/ai_import_gate_provider.dart';
import '../providers/ai_import_intake_provider.dart';
import '../utils/import_file_check.dart';
import '../utils/import_messages.dart';

/// Choose the photos, images or PDFs for an AI import, upload them and start
/// the import. Reached from the Workouts and Programs app bars
/// ([AiImportButton]).
///
/// It checks first ([aiImportGateProvider]): before the first import it shows
/// the notice naming Anthropic, and when the user can't import right now it
/// says why instead of offering files to choose. Declining the notice uploads
/// nothing, and the upload policy refuses files from a user who hasn't
/// accepted it.
class AiImportScreen extends ConsumerWidget {
  const AiImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiImportIntakeProvider);
    final limitsAsync = ref.watch(aiImportLimitsProvider);
    final gateAsync = ref.watch(aiImportGateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Import from file')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: state.phase == ImportIntakePhase.started
                  ? _Started(jobId: state.jobId)
                  : switch ((gateAsync, limitsAsync)) {
                      // Once the intake is under way, a re-check (which could
                      // now see this user's own running import) can't take it
                      // away.
                      (_, AsyncData(value: final limits)) when state.phase != ImportIntakePhase.selecting ||
                          state.pages.isNotEmpty => _Intake(state: state, limits: limits),
                      (AsyncData(value: final check), AsyncData(value: final limits)) when check.allowed => _Intake(
                        state: state,
                        limits: limits,
                      ),
                      (AsyncData(value: final check), _) when check.reason == 'consent_required' => const _Notice(),
                      (AsyncData(value: final check), _) when !check.allowed => _Refused(check: check),
                      (AsyncError(), _) || (_, AsyncError()) => _LoadError(
                        onRetry: () {
                          ref.invalidate(aiImportGateProvider);
                          ref.invalidate(aiImportLimitsProvider);
                        },
                      ),
                      _ => const Center(child: CircularProgressIndicator()),
                    },
            ),
          ),
        ),
      ),
    );
  }
}

class _Intake extends ConsumerWidget {
  const _Intake({required this.state, required this.limits});

  final ImportIntakeState state;
  final AiImportLimits limits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final notifier = ref.read(aiImportIntakeProvider.notifier);
    final canTakePhoto = ref.watch(importFilePickerProvider).canTakePhoto;
    final editable = !state.isBusy;
    final imagesFull = state.pages.length >= limits.maxImages;
    final pdfsFull = state.pages.length >= limits.maxPdfPages;

    final pickerStyle = tokens.secondaryButtonStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add photos of a workout or program, or PDFs of one, such as a file for each week. '
          'An import is up to ${limits.maxImages} images, or PDFs with up to '
          '${limits.maxPdfPages} pages in total, each up to ${formatMegabytes(limits.maxPdfBytes)}.',
          key: const Key('ai_import_limits_text'),
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        if (canTakePhoto) ...[
          FilledButton.icon(
            key: const Key('ai_import_take_photo'),
            style: pickerStyle,
            onPressed: editable && !state.isPdf && !imagesFull ? notifier.takePhoto : null,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Take photo'),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          key: const Key('ai_import_choose_images'),
          style: pickerStyle,
          onPressed: editable && !state.isPdf && !imagesFull ? notifier.chooseImages : null,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Choose images'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('ai_import_choose_pdf'),
          style: pickerStyle,
          onPressed: editable && !state.hasImages && !pdfsFull ? notifier.choosePdfs : null,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Choose PDFs'),
        ),
        if (state.phase == ImportIntakePhase.preparing) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(key: Key('ai_import_preparing')),
        ],
        if (state.pages.isNotEmpty) ...[
          const SizedBox(height: 20),
          ListGroup(
            key: const Key('ai_import_pages'),
            header: ListGroupHeader(
              title: state.isPdf ? 'PDFS' : 'IMAGES',
              trailing: Text(
                !state.isPdf
                    ? '${state.pages.length}/${limits.maxImages}'
                    : state.pdfPagesKnown
                    ? '${state.pdfPageTotal}/${limits.maxPdfPages} pages'
                    : '${state.pages.length} ${state.pages.length == 1 ? 'file' : 'files'}',
                key: const Key('ai_import_pages_count'),
                style: tokens.eyebrow,
              ),
            ),
            children: [
              for (var i = 0; i < state.pages.length; i++)
                _PageRow(index: i, page: state.pages[i], onRemove: editable ? () => notifier.removeAt(i) : null),
            ],
          ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: 16),
          Text(
            state.error!,
            key: const Key('ai_import_error'),
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        if (state.isBusy && state.phase != ImportIntakePhase.preparing)
          _Progress(state: state, onCancel: state.canCancel ? notifier.cancel : null)
        else
          FilledButton(
            key: const Key('ai_import_upload'),
            onPressed: editable && state.pages.isNotEmpty ? () => notifier.submit() : null,
            child: const Text('Upload and import'),
          ),
      ],
    );
  }
}

/// One file: a thumbnail, its number and size, and a remove button. The
/// button sits in a `Row` beside the text, not in a tile's trailing slot, so
/// it stays its own semantics node.
class _PageRow extends StatelessWidget {
  const _PageRow({required this.index, required this.page, required this.onRemove});

  final int index;
  final ImportPage page;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NomorexTokens.of(context).palette;
    final isPdf = page.type == ImportFileType.pdf;
    final label = isPdf ? (page.name ?? 'PDF ${index + 1}') : 'Page ${index + 1}';
    final pageCount = page.pdfPages;
    final details = [
      formatMegabytes(page.bytes.length),
      if (pageCount != null) '$pageCount ${pageCount == 1 ? 'page' : 'pages'}',
    ].join(' · ');

    return GroupableTile(
      key: Key('ai_import_page_$index'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(NomorexSizes.radiusSm),
            child: SizedBox.square(
              dimension: 48,
              child: isPdf
                  ? ColoredBox(color: palette.bg3, child: const Icon(Icons.picture_as_pdf_outlined))
                  : Image.memory(page.bytes, fit: BoxFit.cover, cacheWidth: 96, gaplessPlayback: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                Text(
                  details,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('ai_import_remove_$index'),
            tooltip: 'Remove ${isPdf ? label : 'page ${index + 1}'}',
            onPressed: onRemove,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state, required this.onCancel});

  final ImportIntakeState state;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final total = state.pages.length;
    final (label, value) = switch (state.phase) {
      ImportIntakePhase.checking => ('Checking your import limits…', null),
      ImportIntakePhase.uploading => (
        total == 1 ? 'Uploading…' : 'Uploading ${state.uploaded + 1 > total ? total : state.uploaded + 1} of $total…',
        total == 0 ? null : state.uploaded / total,
      ),
      _ => ('Starting the import…', null),
    };
    return Column(
      key: const Key('ai_import_progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, key: const Key('ai_import_progress_label')),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: value?.toDouble()),
        if (onCancel != null) ...[
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('ai_import_cancel'),
            style: NomorexTokens.of(context).secondaryButtonStyle,
            onPressed: onCancel,
            child: const Text('Cancel upload'),
          ),
        ],
      ],
    );
  }
}

class _Started extends ConsumerWidget {
  const _Started({required this.jobId});

  final String? jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('ai_import_started'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Import started', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          "Your files are uploaded and being read. It's safe to leave this screen.",
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (jobId != null) ...[
          const SizedBox(height: 8),
          SelectableText('Job $jobId', style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('ai_import_another'),
          style: NomorexTokens.of(context).secondaryButtonStyle,
          onPressed: () => ref.read(aiImportIntakeProvider.notifier).reset(),
          child: const Text('Import something else'),
        ),
      ],
    );
  }
}

/// The one-time notice before a user's first upload. Accepting records it in
/// `ai_import_consents`; "Not now" leaves without uploading anything.
class _Notice extends ConsumerStatefulWidget {
  const _Notice();

  @override
  ConsumerState<_Notice> createState() => _NoticeState();
}

class _NoticeState extends ConsumerState<_Notice> {
  bool _saving = false;
  String? _error;

  Future<void> _accept() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(aiImportGateProvider.notifier).acceptNotice();
    } catch (e) {
      debugPrint('[ai_import] recording the notice failed: $e');
      if (mounted) {
        setState(() {
          _saving = false;
          _error = "Couldn't save your answer. Check your connection and try again.";
        });
      }
    }
  }

  void _decline() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppConstants.routeHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    return Column(
      key: const Key('ai_import_notice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Before your first import', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text(
          'Imports are read by Claude, an AI model made by Anthropic. The photos or PDF you upload are '
          'sent to Anthropic, which reads them to find the workout or program in them.',
        ),
        const SizedBox(height: 12),
        const Text(
          'Your files are deleted from NoMoreX once you save or discard the import, or after 7 days if you do '
          'neither.',
        ),
        const SizedBox(height: 12),
        const Text(
          "Only upload what you're happy to share: leave out people's faces and personal details such as "
          'names, addresses or medical notes.',
        ),
        const SizedBox(height: 12),
        const Text("AI can misread things, so you'll check everything it read before anything is saved."),
        if (_error case final error?) ...[
          const SizedBox(height: 16),
          Text(error, key: const Key('ai_import_notice_error'), style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('ai_import_notice_accept'),
          onPressed: _saving ? null : _accept,
          child: const Text('Accept and continue'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('ai_import_notice_decline'),
          style: tokens.secondaryButtonStyle,
          onPressed: _saving ? null : _decline,
          child: const Text('Not now'),
        ),
      ],
    );
  }
}

/// Why the user can't import right now: switched off, an import already
/// running, or a cap reached (which one, and when it resets).
class _Refused extends StatelessWidget {
  const _Refused({required this.check});

  final AiImportCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final running = check.reason == 'active_import';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(importCheckMessage(check), key: const Key('ai_import_refused'), style: theme.textTheme.bodyLarge),
        if (running) ...[
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('ai_import_refused_home'),
            onPressed: () => context.go(AppConstants.routeHome),
            child: const Text('See it on Home'),
          ),
        ],
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Couldn't check whether you can import right now. Check your connection and try again.",
          key: const Key('ai_import_limits_error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
