import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../models/program.dart';
import '../../models/program_day.dart';
import '../../models/program_week.dart';
import '../../providers/program_detail_provider.dart';
import '../../utils/program_edit_summary.dart';
import '../../widgets/add_day_dialog.dart';
import 'program_edit_actions.dart';
import 'widgets/edit_chrome.dart';

/// One week of the phone editor: a bar to switch weeks in place, then a card
/// per day listing every exercise as "4 × 3 · 20 kg". Tapping a day opens it
/// ([ProgramDayEditScreen]).
class ProgramWeekEditScreen extends ConsumerWidget {
  const ProgramWeekEditScreen({super.key, required this.programId, required this.weekId});

  final String programId;
  final String weekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(programDetailProvider(programId));
    final program = detail.asData?.value;
    final week = program?.weeks.where((w) => w.id == weekId).firstOrNull;
    void leave() => context.canPop() ? context.pop() : context.go(AppConstants.routeProgramEdit(programId));

    return Scaffold(
      appBar: AppBar(
        // Always up one level, even when the week was opened from a link and
        // there's nothing behind it.
        leading: BackButton(onPressed: leave),
        title: week == null
            ? const Text('Edit program')
            : StackedTitle(crumb: program!.name, title: weekTitle(week)),
        actions: [
          if (week != null)
            IconButton(
              key: const Key('edit_week_more'),
              tooltip: '${weekTitle(week)} options',
              icon: const Icon(Icons.more_horiz),
              onPressed: () => showWeekActions(context, ref, program: program!, week: week, onDeleted: leave),
            ),
        ],
        bottom: week == null
            ? null
            : SelectorStrip(
                semanticLabel: 'Weeks',
                items: [
                  for (final w in program!.weeks)
                    StripItem(key: w.id, label: 'W${w.weekNumber}', semanticLabel: 'Week ${w.weekNumber}'),
                ],
                selectedKey: week.id,
                onSelect: (id) {
                  if (id != week.id) replaceWithWeek(context, programId, id);
                },
                addTooltip: 'Add week',
                onAdd: () async {
                  final notifier = ref.read(programDetailProvider(programId).notifier);
                  await notifier.addWeek();
                  final updated = await ref.read(programDetailProvider(programId).future);
                  if (!context.mounted || updated.weeks.isEmpty) return;
                  replaceWithWeek(context, programId, updated.weeks.last.id);
                },
              ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text("Couldn't load the program. Try again.", style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        data: (program) => week == null
            ? GoneState(message: 'This week no longer exists.', actionLabel: 'Back to the program', onAction: leave)
            : _WeekBody(program: program, week: week),
      ),
    );
  }
}

class _WeekBody extends ConsumerWidget {
  const _WeekBody({required this.program, required this.week});

  final Program program;
  final ProgramWeek week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    return ListView(
      padding: contentPadding(context, bottom: 32),
      children: [
        if (week.days.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No days yet. Add one to start planning this week.', style: tokens.bodySmall),
          )
        else
          for (final day in week.days) ...[
            _DayCard(key: ValueKey(day.id), program: program, week: week, day: day),
            const SizedBox(height: 12),
          ],
        FilledButton.icon(
          key: const Key('edit_week_add_day'),
          style: tokens.secondaryButtonStyle,
          onPressed: () => showAddDayDialog(context, ref, programId: program.id, week: week),
          icon: const Icon(Icons.add),
          label: const Text('Add day'),
        ),
      ],
    );
  }
}

/// A day: title and size, ⋯, then every exercise with its sets and load.
class _DayCard extends ConsumerWidget {
  const _DayCard({super.key, required this.program, required this.week, required this.day});

  final Program program;
  final ProgramWeek week;
  final ProgramDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    final theme = Theme.of(context);
    final unit = ref.watch(unitPreferenceProvider);

    return Semantics(
      container: true,
      button: true,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('edit_day_card_${day.id}'),
          onTap: () => context.push(AppConstants.routeProgramEditDay(program.id, day.id)),
          hoverColor: tokens.palette.bg3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(day.title, style: theme.textTheme.titleMedium),
                            Text(daySummary(day), style: tokens.bodySmall.copyWith(color: tokens.fg3)),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('edit_day_more_${day.id}'),
                      tooltip: '${day.title} options',
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () => showDayActions(context, ref, program: program, week: week, day: day),
                    ),
                  ],
                ),
                if (!day.isRestDay && day.exercises.isNotEmpty) const SizedBox(height: 6),
                if (!day.isRestDay)
                  for (final e in day.exercises)
                    Padding(
                      padding: const EdgeInsets.only(right: 12, top: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(e.exerciseName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                          ),
                          const SizedBox(width: 12),
                          Text(exerciseLine(e, unit), style: tokens.bodySmall.copyWith(color: tokens.fg3)),
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
