import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/copy_errors.dart';
import '../../../core/utils/owner_name.dart';
import '../../auth/providers/auth_provider.dart';
import '../../programs/models/program_week.dart';
import '../../programs/providers/program_copy_count_provider.dart';
import '../../programs/providers/programs_provider.dart';
import '../../programs/utils/program_day_summary.dart';
import '../../../shared/widgets/list_group.dart';
import '../../programs/widgets/program_day_card.dart';
import '../../programs/widgets/start_program_dialog.dart';
import '../providers/community_program_detail_provider.dart';

/// Read-only preview of another user's public program, mirroring
/// [CommunityWorkoutDetailScreen]. The program itself is never editable here;
/// "Save to my programs" / "Start program" instead copy it into the viewer's
/// own programs (the `copy_program` RPC) — a run always belongs to a copy the
/// viewer owns, never to the author's template, so it survives the author
/// changing or removing theirs.
class CommunityProgramDetailScreen extends ConsumerWidget {
  const CommunityProgramDetailScreen({super.key, required this.programId});
  final String programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(communityProgramDetailProvider(programId));
    final colorScheme = Theme.of(context).colorScheme;
    final viewerId = ref.watch(currentAuthUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Program'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: _Badge('Read only')),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: TextStyle(color: colorScheme.error)),
        ),
        data: (program) {
          final weeks = program.weeks.length;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(program.name, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'by ${ownerDisplayName(program.ownerDisplayName)} · '
                '$weeks ${weeks == 1 ? 'week' : 'weeks'}',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
              if (program.description != null && program.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(program.description!),
              ],
              // Nothing to copy from your own program (FR-018).
              if (viewerId != null && program.userId != viewerId) ...[
                const SizedBox(height: 16),
                _CopyActions(
                  programId: program.id,
                  dayCount: program.weeks.fold<int>(0, (sum, w) => sum + w.days.length),
                ),
              ],
              const SizedBox(height: 16),
              if (program.weeks.isEmpty)
                const Center(child: Text('This program has no weeks yet.'))
              else
                for (final week in program.weeks) _WeekSection(week: week, programId: programId),
            ],
          );
        },
      ),
    );
  }
}

/// "Start program" / "Save to my programs". Both make a private copy in the
/// viewer's own programs; Start also begins a dated run of that copy.
class _CopyActions extends ConsumerStatefulWidget {
  const _CopyActions({required this.programId, required this.dayCount});
  final String programId;
  final int dayCount;

  @override
  ConsumerState<_CopyActions> createState() => _CopyActionsState();
}

class _CopyActionsState extends ConsumerState<_CopyActions> with AutomaticKeepAliveClientMixin {
  bool _busy = false;

  /// The SnackBar this screen is currently showing, if any. It lives on the
  /// app-wide ScaffoldMessenger, so without this it would follow the user back
  /// to the list; the PopScope in [build] closes it when the screen is popped.
  /// (Not from dispose(): that also runs while the whole app tree is torn
  /// down, when the ScaffoldMessenger itself is going away.)
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snackBar;

  // Keep the buttons — and so the PopScope — alive while they're scrolled out
  // of the ListView.
  @override
  bool get wantKeepAlive => true;

  void _showSnackBar(ScaffoldMessengerState messenger, SnackBar snackBar) {
    // Once the screen is gone there's nothing left to close it, so only track
    // (and only let persist) SnackBars shown while it's still here.
    if (!mounted) {
      messenger.showSnackBar(snackBar);
      return;
    }
    // Ours must be the current SnackBar for close() to apply to it.
    messenger.removeCurrentSnackBar();
    final controller = messenger.showSnackBar(snackBar);
    _snackBar = controller;
    controller.closed.then((_) {
      if (identical(_snackBar, controller)) _snackBar = null;
    });
  }

  Future<void> _start() async {
    final startDate = await showStartProgramDialog(context, dayCount: widget.dayCount);
    if (startDate == null || !mounted) return;
    await _copy(startDate: startDate);
  }

  Future<void> _copy({DateTime? startDate}) => _run(
    startDate: startDate,
    notifier: ref.read(programsProvider.notifier),
    router: GoRouter.of(context),
    messenger: ScaffoldMessenger.of(context),
  );

  // Everything the SnackBar actions use is captured up front: a save can
  // finish after the user has left the screen, so View/Retry must never reach
  // for this State's context.
  Future<void> _run({
    DateTime? startDate,
    required ProgramsNotifier notifier,
    required GoRouter router,
    required ScaffoldMessengerState messenger,
  }) async {
    if (mounted) setState(() => _busy = true);
    try {
      final result = await notifier.saveCommunityProgram(widget.programId, startDate: startDate);
      if (result.instanceId != null) {
        messenger.showSnackBar(const SnackBar(content: Text('Program started.')));
        // Don't yank the user somewhere if they've already left this screen.
        if (mounted) {
          router.pushReplacement(AppConstants.routeProgramInstanceDetail(result.instanceId!));
        }
      } else {
        _showSnackBar(
          messenger,
          SnackBar(
            content: const Text('Saved to your programs'),
            // An action makes a SnackBar persist by default; this is a
            // confirmation, so let it time out like any other.
            persist: false,
            action: SnackBarAction(
              label: 'View',
              onPressed: () => router.push(AppConstants.routeProgramDetail(result.programId)),
            ),
          ),
        );
      }
    } catch (e) {
      _showSnackBar(
        messenger,
        SnackBar(
          content: Text(copyErrorMessage(e)),
          // Keep Retry on screen while the user is here; leaving closes it.
          persist: mounted,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _run(
              startDate: startDate,
              notifier: notifier,
              router: router,
              messenger: messenger,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final tokens = Theme.of(context).extension<NomorexTokens>();
    final copies = ref.watch(programCopyCountProvider(widget.programId)).asData?.value ?? 0;
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _snackBar?.close();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const Key('community_program_start'),
            onPressed: _busy ? null : _start,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: const Text('Start program'),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('community_program_save'),
            style: tokens?.secondaryButtonStyle,
            onPressed: _busy ? null : () => _copy(),
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save to my programs'),
          ),
          if (copies > 0) ...[
            const SizedBox(height: 6),
            Text(
              copies == 1 ? "You've saved this once" : "You've saved this $copies times",
              key: const Key('community_program_saved_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({required this.week, required this.programId});

  final ProgramWeek week;
  final String programId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Week ${week.weekNumber}${week.label != null ? ' — ${week.label}' : ''}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (week.notes != null && week.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(week.notes!, style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 8),
          ListGroup(
            children: [
              for (final day in week.days)
                ProgramDayCard(
                  title: day.title,
                  subtitle: programDaySubtitle(day),
                  showChevron: programDayHasContent(day),
                  // ProgramDayDetailScreen has no edit affordances of its own, so
                  // it doubles as the read-only day view for a foreign program.
                  onTap: programDayHasContent(day)
                      ? () => context.push(AppConstants.routeProgramDayDetail(programId, day.id))
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
    );
  }
}
