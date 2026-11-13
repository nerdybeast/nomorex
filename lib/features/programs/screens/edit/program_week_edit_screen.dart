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
          _DayList(program: program, week: week),
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

/// The week's days, dragged by their handles to reorder within the week.
/// The new order shows at once and holds until the save comes back.
class _DayList extends ConsumerStatefulWidget {
  const _DayList({required this.program, required this.week});

  final Program program;
  final ProgramWeek week;

  @override
  ConsumerState<_DayList> createState() => _DayListState();
}

class _DayListState extends ConsumerState<_DayList> {
  List<String>? _pending;

  Future<void> _reorder(List<ProgramDay> days, int oldIndex, int newIndex) async {
    final ids = days.map((d) => d.id).toList();
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex, moved);
    setState(() => _pending = ids);
    try {
      await ref.read(programDetailProvider(widget.program.id).notifier).reorderDays(ids);
    } catch (_) {
      if (mounted) showEditSnack(context, "Couldn't move the day. Try again.");
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final byId = {for (final d in widget.week.days) d.id: d};
    final pending = _pending;
    final days = pending != null && pending.length == byId.length && pending.every(byId.containsKey)
        ? [for (final id in pending) byId[id]!]
        : widget.week.days;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: days.length,
      itemBuilder: (context, i) => Padding(
        key: ValueKey(days[i].id),
        padding: const EdgeInsets.only(bottom: 12),
        child: _DayCard(program: widget.program, week: widget.week, day: days[i], index: i),
      ),
      onReorderItem: (oldIndex, newIndex) => _reorder(days, oldIndex, newIndex),
    );
  }
}

/// A day: a drag handle, its title and size, ⋯, then every exercise with its
/// sets and load.
class _DayCard extends ConsumerWidget {
  const _DayCard({required this.program, required this.week, required this.day, required this.index});

  final Program program;
  final ProgramWeek week;
  final ProgramDay day;

  /// Its place in the list, for the drag handle.
  final int index;

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
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      // Hidden from screen readers: the list gives each day
                      // move up/down actions of its own.
                      child: ExcludeSemantics(
                        child: SizedBox(
                          key: ValueKey('edit_day_handle_${day.id}'),
                          width: 36,
                          height: 48,
                          child: Icon(Icons.drag_indicator, size: 20, color: tokens.fg3),
                        ),
                      ),
                    ),
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
                      padding: const EdgeInsets.only(left: 36, right: 12, top: 2),
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
