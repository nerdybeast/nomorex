import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/start_option_tile.dart';
import '../core/ai_provider.dart';
import '../core/ai_task.dart';
import '../core/model_router_provider.dart';
import '../models/ai_import_limits.dart';
import '../providers/ai_import_alerts_provider.dart';
import '../providers/ai_import_gate_provider.dart';
import '../providers/ai_import_intake_provider.dart';
import '../providers/ai_import_path_provider.dart';
import '../utils/ai_provider_info.dart';
import '../utils/import_file_check.dart';
import '../utils/import_messages.dart';

/// Choose the photos, images or PDFs for an AI import, and read them.
/// Reached from the "New" menus: the sidebar's, and the phone's + sheet
/// (`kAiImportAction`).
///
/// Which way it reads them is [aiImportPathProvider]'s choice:
/// - **With the lifter's own key** ([ImportPath.local]): in the app, straight
///   to their provider. A one-time notice per provider comes first; a progress
///   screen shows while it reads; the review opens when it's saved. A run that
///   fails or was cut short by the app closing keeps its files on the device
///   and offers "Try again".
/// - **The hosted alpha** ([ImportPath.hosted]): uploaded and read by the `ai`
///   function. It checks first ([aiImportGateProvider]): before the first
///   import it shows the notice naming Anthropic, and when the user can't
///   import right now it says why instead of offering files to choose.
/// - **Neither** ([ImportPath.needsKey]): it offers the AI assistant settings.
class AiImportScreen extends ConsumerStatefulWidget {
  const AiImportScreen({super.key});

  @override
  ConsumerState<AiImportScreen> createState() => _AiImportScreenState();
}

class _AiImportScreenState extends ConsumerState<AiImportScreen> {
  @override
  void initState() {
    super.initState();
    // A run the app was closed in the middle of comes back to try again.
    Future.microtask(() {
      if (mounted) ref.read(aiImportIntakeProvider.notifier).restoreUnfinished();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiImportIntakeProvider);
    final path = ref.watch(aiImportPathProvider);

    // A local run's result is saved: open its review in this screen's place.
    ref.listen(aiImportIntakeProvider, (previous, next) {
      final jobId = next.jobId;
      if (next.phase == ImportIntakePhase.started &&
          next.provider != null &&
          jobId != null &&
          previous?.phase != ImportIntakePhase.started) {
        // Opened here, so the "ready to review" alert would only repeat it.
        ref.read(importAlertSnackBarsProvider).suppress(jobId);
        context.pushReplacement(AppConstants.routeAiImportReview(jobId));
      }
    });

    final Widget body;
    if (state.isRunningLocally || (state.phase == ImportIntakePhase.started && state.provider != null)) {
      body = _LocalProgress(state: state);
    } else if (state.phase == ImportIntakePhase.failed) {
      body = _LocalFailed(state: state);
    } else if (state.phase == ImportIntakePhase.started) {
      body = _Started(jobId: state.jobId);
    } else {
      body = switch (path) {
        ImportPath.local => _localIntake(state),
        ImportPath.hosted => _hostedBody(state),
        ImportPath.needsKey => const _NoKey(),
        ImportPath.unavailable => const _Unavailable(),
        null => const Center(child: CircularProgressIndicator()),
      };
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Import from file')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: body),
          ),
        ),
      ),
    );
  }

  Widget _localIntake(ImportIntakeState state) {
    final cloud = ref.watch(modelForTaskProvider(AiTask.import))?.cloud;
    return switch (ref.watch(aiImportIntakeLimitsProvider)) {
      AsyncData(value: final limits) when cloud != null => _Intake(state: state, limits: limits, provider: cloud),
      AsyncError() => _LoadError(onRetry: () => ref.invalidate(aiImportIntakeLimitsProvider)),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _hostedBody(ImportIntakeState state) {
    final limitsAsync = ref.watch(aiImportIntakeLimitsProvider);
    final gateAsync = ref.watch(aiImportGateProvider);
    return switch ((gateAsync, limitsAsync)) {
      // Once the intake is under way, a re-check (which could now see this
      // user's own running import) can't take it away.
      (_, AsyncData(value: final limits)) when state.phase != ImportIntakePhase.selecting || state.pages.isNotEmpty =>
        _Intake(state: state, limits: limits),
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
    };
  }
}

/// What a run reads, for messages: "3 photos", "1 PDF".
String _filesLabel(ImportIntakeState state) {
  final n = state.pages.length;
  if (state.isPdf) return n == 1 ? '1 PDF' : '$n PDFs';
  return n == 1 ? '1 photo' : '$n photos';
}

class _Intake extends ConsumerWidget {
  const _Intake({required this.state, required this.limits, this.provider});

  final ImportIntakeState state;
  final AiImportLimits limits;

  /// Set when the files are read in the app with this provider's key.
  final CloudAiProvider? provider;

  /// Shows the provider's one-time notice if this device hasn't yet, then
  /// reads the files.
  Future<void> _importLocally(BuildContext context, WidgetRef ref, CloudAiProvider provider) async {
    final seen = await ref.read(aiImportNoticeProvider.future);
    if (!seen.contains(provider)) {
      if (!context.mounted) return;
      final accepted = await showLocalImportNotice(context, provider, isPdf: state.isPdf);
      if (accepted != true) return;
      await ref.read(aiImportNoticeProvider.notifier).accept(provider);
    }
    await ref.read(aiImportIntakeProvider.notifier).runLocally();
  }

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
          '${limits.maxPdfPages} pages in total, each up to ${formatMegabytes(limits.maxPdfBytes)}.'
          '${provider == null ? '' : ' Read with ${provider!.label}, using your key.'}',
          key: const Key('ai_import_limits_text'),
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (provider == null && editable && state.pages.isEmpty)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              key: const Key('ai_import_use_own_key'),
              onPressed: () => context.push(AppConstants.routeAiAssistant),
              child: const Text('Have your own AI key? Set it up'),
            ),
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
            onPressed: editable && state.pages.isNotEmpty
                ? () => provider == null ? notifier.submit() : _importLocally(context, ref, provider!)
                : null,
            child: Text(provider == null ? 'Upload and import' : 'Import ${_filesLabel(state)}'),
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

/// The one-time notice before the first import with [provider] on this
/// device. True when the lifter continues.
Future<bool?> showLocalImportNotice(BuildContext context, CloudAiProvider provider, {required bool isPdf}) {
  final files = isPdf ? 'PDFs' : 'photos';
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final theme = Theme.of(context);
      final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
      return SafeArea(
        child: Padding(
          key: const Key('ai_import_local_notice'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Before your first import with ${provider.label}', style: theme.textTheme.titleLarge),
              const SizedBox(height: 14),
              Text(
                'Your $files go straight from this device to ${provider.company}\'s ${provider.label}, using your '
                "key and under your ${provider.company} account's terms. NoMoreX doesn't receive or keep them.",
                style: muted,
              ),
              if (provider == CloudAiProvider.gemini) ...[
                const SizedBox(height: 12),
                Text("On Gemini's free tier, Google may use them to improve its products.", style: muted),
              ],
              const SizedBox(height: 12),
              Text("AI can misread things, so you'll check everything it read before anything is saved.", style: muted),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('ai_import_local_notice_decline'),
                      style: NomorexTokens.of(context).secondaryButtonStyle,
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Not now'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const Key('ai_import_local_notice_accept'),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Reading in the app: the steps, the time so far, and Cancel. The files stay
/// on this device, so the lifter can leave and the run still finishes and
/// saves; its review then arrives as an alert.
class _LocalProgress extends ConsumerStatefulWidget {
  const _LocalProgress({required this.state});

  final ImportIntakeState state;

  @override
  ConsumerState<_LocalProgress> createState() => _LocalProgressState();
}

class _LocalProgressState extends ConsumerState<_LocalProgress> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final name = state.provider?.label ?? 'Your AI';
    final elapsed = state.readingSince == null ? Duration.zero : DateTime.now().difference(state.readingSince!);
    final clock = '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    final what = switch (state.requestedType) {
      'program' => 'program',
      'workout' => 'workout',
      _ => 'import',
    };
    final reading = state.phase == ImportIntakePhase.reading;
    final saving = state.phase == ImportIntakePhase.saving;

    return Column(
      key: const Key('ai_import_local_progress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Reading your $what', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('$name is reading ${_filesLabel(state)}. This usually takes a minute or two.', style: muted),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Semantics(
              label: 'Elapsed ${elapsed.inSeconds} seconds',
              excludeSemantics: true,
              child: Text(clock, key: const Key('ai_import_elapsed'), style: tokens.weightMd),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ListGroup(
          children: [
            _Step(done: true, label: 'Checked ${_filesLabel(state)}'),
            _Step(done: !reading, active: reading, label: 'Reading with $name', showBar: reading),
            _Step(done: !reading && !saving, active: saving, label: 'Matching exercises to your list'),
            _Step(done: state.phase == ImportIntakePhase.started, label: 'Ready to review'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.phone_android_outlined, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Keep NoMoreX open until it's done. If it stops, your files stay on this device so you can "
                'try again.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('ai_import_cancel'),
          style: tokens.secondaryButtonStyle,
          onPressed: reading ? ref.read(aiImportIntakeProvider.notifier).cancel : null,
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, this.done = false, this.active = false, this.showBar = false});

  final String label;
  final bool done;
  final bool active;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NomorexTokens.of(context).palette;
    final Widget mark = done
        ? Icon(Icons.check_circle, size: 20, color: theme.colorScheme.onSurfaceVariant)
        : active
        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(Icons.radio_button_unchecked, size: 20, color: palette.bg3);
    return GroupableTile(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mark,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  style: active
                      ? theme.textTheme.bodyLarge
                      : theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                if (showBar) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A local run that stopped: failed, or cut short when the app closed. The
/// files are still on this device, so the lifter can try again, change the
/// files, or discard them.
class _LocalFailed extends ConsumerWidget {
  const _LocalFailed({required this.state});

  final ImportIntakeState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final notifier = ref.read(aiImportIntakeProvider.notifier);
    final failure = state.failure;
    final action = failure?.action ?? ImportFailureAction.tryAgain;
    final name = state.provider?.label ?? 'your AI';
    final files = _filesLabel(state);

    final tryAgain = FilledButton.icon(
      key: const Key('ai_import_try_again'),
      style: action == ImportFailureAction.tryAgain ? null : tokens.secondaryButtonStyle,
      onPressed: () => notifier.runLocally(),
      icon: const Icon(Icons.refresh),
      label: const Text('Try again'),
    );
    final settings = FilledButton(
      key: const Key('ai_import_open_settings'),
      onPressed: () => context.push(AppConstants.routeAiAssistant),
      child: Text(action == ImportFailureAction.checkKey ? 'Check key' : 'Choose another provider'),
    );

    return Column(
      key: const Key('ai_import_failed'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(failure?.title ?? 'The import stopped', style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          failure?.message ?? '',
          key: const Key('ai_import_failed_message'),
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        ...switch (action) {
          ImportFailureAction.tryAgain => [tryAgain],
          ImportFailureAction.checkKey || ImportFailureAction.switchProvider => [
            settings,
            const SizedBox(height: 8),
            tryAgain,
          ],
          ImportFailureAction.none => const <Widget>[],
        },
        if (action != ImportFailureAction.none) const SizedBox(height: 8),
        FilledButton(
          key: const Key('ai_import_change_files'),
          style: action == ImportFailureAction.none ? null : tokens.secondaryButtonStyle,
          onPressed: notifier.backToFiles,
          child: const Text('Change files'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('ai_import_discard_run'),
          style: tokens.secondaryButtonStyle,
          onPressed: () => notifier.discardRun(),
          child: Text(state.isPdf ? 'Discard PDFs' : 'Discard photos'),
        ),
        if (action != ImportFailureAction.none) ...[
          const SizedBox(height: 16),
          Text(
            'Trying again reads all $files from the start and uses your $name key again.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// No key yet, and the hosted alpha is off: the way in is the settings.
class _NoKey extends StatelessWidget {
  const _NoKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('ai_import_no_key'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Icon(Icons.key_outlined, size: 32, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Text('Add an AI key to import', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'NoMoreX reads your photos and PDFs with an AI you choose: Gemini, Claude or ChatGPT. '
          'Gemini has a free key that takes a couple of minutes to get.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('ai_import_set_up_key'),
          onPressed: () => context.push(AppConstants.routeAiAssistant),
          child: const Text('Set up AI assistant'),
        ),
        const SizedBox(height: 24),
        ListGroup(
          header: const ListGroupHeader(title: 'Or'),
          children: [
            StartOptionTile(
              key: const Key('ai_import_by_hand'),
              icon: Icons.add,
              title: 'Enter it by hand',
              detail: 'Start a new program or workout yourself.',
              onTap: () => context.go(AppConstants.routeTraining),
            ),
          ],
        ),
      ],
    );
  }
}

/// No key can be stored here and the hosted alpha is off. The entry points
/// are hidden then, so this is only reached by a link.
class _Unavailable extends StatelessWidget {
  const _Unavailable();

  @override
  Widget build(BuildContext context) => Text(
    "Importing isn't available on this device: it can't store an AI key safely.",
    key: const Key('ai_import_unavailable'),
    style: Theme.of(context).textTheme.bodyLarge,
  );
}
