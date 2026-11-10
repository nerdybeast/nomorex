import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/list_group.dart';
import '../models/ai_import_limits.dart';
import '../providers/ai_import_intake_provider.dart';
import '../utils/import_file_check.dart';

/// Choose the photos, images or PDF for an AI import, upload them and start
/// the import.
///
/// Debug builds reach it from Profile until launch (#88), which adds the
/// one-time notice and the real entry points. Until then an upload needs an
/// `ai_import_consents` row for the user, or the bucket policy refuses it.
class AiImportScreen extends ConsumerWidget {
  const AiImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiImportIntakeProvider);
    final limitsAsync = ref.watch(aiImportLimitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Import from file')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: switch (limitsAsync) {
                AsyncData(:final value) =>
                  state.phase == ImportIntakePhase.started
                      ? _Started(jobId: state.jobId)
                      : _Intake(state: state, limits: value),
                AsyncError() => Text(
                  "Couldn't load the import limits. Check your connection and try again.",
                  key: const Key('ai_import_limits_error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
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

    final pickerStyle = tokens.secondaryButtonStyle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Add photos of a workout or program, or a PDF of one. '
          'An import is up to ${limits.maxImages} images, or one PDF of up to '
          '${limits.maxPdfPages} pages and ${formatMegabytes(limits.maxPdfBytes)}.',
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
          onPressed: editable && state.pages.isEmpty ? notifier.choosePdf : null,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: const Text('Choose PDF'),
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
              title: state.isPdf ? 'PDF' : 'IMAGES',
              trailing: state.isPdf ? null : Text('${state.pages.length}/${limits.maxImages}', style: tokens.eyebrow),
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
    final label = isPdf ? 'PDF' : 'Page ${index + 1}';

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
                Text(label, style: theme.textTheme.bodyLarge),
                Text(
                  formatMegabytes(page.bytes.length),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            key: Key('ai_import_remove_$index'),
            tooltip: 'Remove ${isPdf ? 'PDF' : 'page ${index + 1}'}',
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
