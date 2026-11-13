import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/copy_errors.dart';
import '../../../../shared/widgets/auto_save_field.dart';
import '../../../../shared/widgets/copied_from_badge.dart';
import '../../../../shared/widgets/list_group.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../shared/widgets/summary_card.dart';
import '../../../../shared/widgets/toggle_card.dart';
import '../../models/program.dart';
import '../../models/program_day.dart';
import '../../models/program_week.dart';
import '../../providers/program_detail_provider.dart';
import '../../utils/program_edit_summary.dart';
import 'program_edit_actions.dart';

/// The phone editor's top level: the program's details behind one row, then
/// a card per week listing its days and their first lifts. Tapping a week
/// opens it ([ProgramWeekEditScreen]).
class ProgramEditOverviewScreen extends ConsumerWidget {
  const ProgramEditOverviewScreen({super.key, required this.programId});

  final String programId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(programDetailProvider(programId));
    final tokens = NomorexTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit program'),
        actions: [TextButton(onPressed: () => context.pop(), child: const Text('Done'))],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text("Couldn't load the program. Try again.", style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        data: (program) {
          final days = program.weeks.fold<int>(0, (n, w) => n + w.days.length);
          return ListView(
            padding: contentPadding(context, bottom: 32),
            children: [
              if (program.isCopy) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: CopiedFromBadge(
                    isCopy: true,
                    isImported: program.isImported,
                    copiedFromUserId: program.copiedFromUserId,
                    copiedFromDisplayName: program.copiedFromDisplayName,
                    copiedFromSourceId: program.copiedFromProgramId,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ListGroup(children: [_DetailsRow(program: program)]),
              const SizedBox(height: 24),
              Text(
                '${pluralize(program.weeks.length, 'week')} · ${pluralize(days, 'day')}'.toUpperCase(),
                style: tokens.eyebrow,
              ),
              const SizedBox(height: 8),
              if (program.weeks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('No weeks yet. Add one to start planning.', style: tokens.bodySmall),
                )
              else
                for (final week in program.weeks) ...[
                  _WeekCard(key: ValueKey(week.id), program: program, week: week),
                  const SizedBox(height: 12),
                ],
              FilledButton.icon(
                key: const Key('edit_program_add_week'),
                style: tokens.secondaryButtonStyle,
                onPressed: () => ref.read(programDetailProvider(programId).notifier).addWeek(),
                icon: const Icon(Icons.add),
                label: const Text('Add week'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The program's name, with what the details sheet holds underneath.
class _DetailsRow extends StatelessWidget {
  const _DetailsRow({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final hasDescription = program.description?.trim().isNotEmpty ?? false;
    return GroupableTile(
      key: const Key('edit_program_details'),
      onTap: () => _showDetailsSheet(context, program.id),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(program.name, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  'Details · ${hasDescription ? 'description' : 'no description'}, ${program.isPublic ? 'public' : 'private'}',
                  style: tokens.bodySmall.copyWith(color: tokens.fg3),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: tokens.fg3),
        ],
      ),
    );
  }
}

/// Name, description and Public, in a sheet over the overview. Each saves as
/// it changes, like the rest of the editor.
Future<void> _showDetailsSheet(BuildContext context, String programId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Consumer(
      builder: (ctx, ref, _) {
        final program = ref.watch(programDetailProvider(programId)).asData?.value;
        if (program == null) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
        final notifier = ref.read(programDetailProvider(programId).notifier);
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Program details', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 16),
                AutoSaveField(
                  initialValue: program.name,
                  labelText: 'Name',
                  onChanged: (v) {
                    final trimmed = v.trim();
                    if (trimmed.isNotEmpty) notifier.updateProgramMeta(name: trimmed);
                  },
                ),
                const SizedBox(height: 16),
                AutoSaveField(
                  initialValue: program.description,
                  labelText: 'Description',
                  maxLines: 4,
                  onChanged: (v) => notifier.updateProgramMeta(description: v),
                ),
                const SizedBox(height: 16),
                ToggleCard(
                  title: 'Public',
                  subtitle: program.isImported
                      ? kImportNotShareableMessage
                      : program.isCopy
                      ? kCopyNotShareableMessage
                      : 'Other users can view this program',
                  value: program.isPublic,
                  // Copies can't be published — the database rejects it too.
                  onChanged: program.isCopy ? null : (v) => notifier.updateVisibility(v),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: NomorexTokens.of(ctx).secondaryButtonStyle,
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// One week: its title and size, then each day with its first lifts. The
/// card opens the week; ⋯ holds duplicate, rename, move and delete.
class _WeekCard extends ConsumerWidget {
  const _WeekCard({super.key, required this.program, required this.week});

  final Program program;
  final ProgramWeek week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    final theme = Theme.of(context);
    void open() => context.push(AppConstants.routeProgramEditWeek(program.id, week.id));

    // An explicit button, so the card is announced as something to open
    // rather than as a group around its ⋯ button.
    return Semantics(
      container: true,
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('edit_week_card_${week.id}'),
          onTap: open,
          hoverColor: tokens.palette.bg3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(weekTitle(week), style: theme.textTheme.titleMedium),
                            Text(weekSummary(week), style: tokens.bodySmall.copyWith(color: tokens.fg3)),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('edit_week_more_${week.id}'),
                      tooltip: '${weekTitle(week)} options',
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () => showWeekActions(context, ref, program: program, week: week),
                    ),
                  ],
                ),
                if (week.days.isNotEmpty) const SizedBox(height: 6),
                for (final day in week.days)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(day.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                        ),
                        Expanded(child: _DayLifts(day: day)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A day's first two lifts, with "+4" kept clear of the ellipsis when the
/// names run long: "Muscle Snatch · Snatch +4".
class _DayLifts extends StatelessWidget {
  const _DayLifts({required this.day});

  final ProgramDay day;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    if (day.isRestDay || day.exercises.isEmpty) {
      return Text(day.isRestDay ? 'Rest day' : 'No exercises yet', style: tokens.bodySmall.copyWith(color: tokens.fg3));
    }
    final names = [for (final e in day.exercises) e.exerciseName];
    final more = names.length - 2;
    return Row(
      children: [
        Flexible(
          child: Text(names.take(2).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: tokens.bodySmall),
        ),
        if (more > 0) Text('  +$more', style: tokens.bodySmall.copyWith(color: tokens.fg3)),
      ],
    );
  }
}
