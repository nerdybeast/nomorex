import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../exercises/widgets/exercise_picker_sheet.dart';
import '../../../profile/providers/profile_provider.dart';
import '../../../workouts/widgets/exercise_editor_card.dart';
import '../../models/program.dart';
import '../../models/program_day.dart';
import '../../models/program_exercise.dart';
import '../../models/program_week.dart';
import '../../providers/program_detail_provider.dart';
import '../../utils/program_edit_summary.dart';
import '../../widgets/add_day_dialog.dart';
import 'program_edit_actions.dart';
import 'widgets/edit_chrome.dart';
import 'widgets/exercise_edit_sheet.dart';

/// One day of the phone editor: tabs to switch days within the week, then
/// the day's exercises in a list you drag to reorder. Tapping an exercise
/// edits it in a sheet ([showExerciseEditSheet]).
class ProgramDayEditScreen extends ConsumerStatefulWidget {
  const ProgramDayEditScreen({super.key, required this.programId, required this.dayId});

  final String programId;
  final String dayId;

  @override
  ConsumerState<ProgramDayEditScreen> createState() => _ProgramDayEditScreenState();
}

class _ProgramDayEditScreenState extends ConsumerState<ProgramDayEditScreen> with JustAddedExerciseHighlight {
  final _scroll = ScrollController();

  String get programId => widget.programId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Back to the week, or to the program when there's nothing to go back to.
  void _leave(ProgramWeek? week) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(week == null
          ? AppConstants.routeProgramEdit(programId)
          : AppConstants.routeProgramEditWeek(programId, week.id));
    }
  }

  Future<void> _addExercise(ProgramDay day) async {
    final provider = programDetailProvider(programId);
    final beforeIds = {for (final e in day.exercises) e.id};
    final added = await showExercisePickerSheet(
      context,
      addedExerciseIds: {for (final e in day.exercises) e.exerciseId},
      onPick: (exercise) => ref.read(provider.notifier).addExercise(day.id, exercise.id),
    );
    if (added == null || !mounted) return;
    final program = await ref.read(provider.future);
    final after = program.weeks.expand((w) => w.days).where((d) => d.id == day.id).firstOrNull?.exercises ?? const [];
    final newRow = after.where((e) => !beforeIds.contains(e.id) && e.exerciseId == added.id).lastOrNull;
    if (newRow != null) highlightAddedExercise(newRow.id, scrollController: _scroll);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(programDetailProvider(programId));
    final program = detail.asData?.value;
    ProgramWeek? week;
    ProgramDay? day;
    for (final w in program?.weeks ?? const <ProgramWeek>[]) {
      for (final d in w.days) {
        if (d.id == widget.dayId) {
          week = w;
          day = d;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => _leave(week)),
        title: day == null ? const Text('Edit program') : StackedTitle(crumb: weekTitle(week!), title: day.title),
        actions: [
          if (day != null)
            IconButton(
              key: const Key('edit_day_more'),
              tooltip: '${day.title} options',
              icon: const Icon(Icons.more_horiz),
              onPressed: () => showDayActions(
                context,
                ref,
                program: program!,
                week: week!,
                day: day!,
                onDeleted: () => _leave(week),
              ),
            ),
        ],
        bottom: day == null
            ? null
            : SelectorStrip(
                semanticLabel: 'Days in ${weekTitle(week!)}',
                items: [
                  for (final d in week.days)
                    StripItem(
                      key: d.id,
                      label: d.title,
                      detail: d.isRestDay ? 'rest' : '${d.exercises.length} ex',
                      semanticLabel: '${d.title}, ${daySummary(d)}',
                    ),
                ],
                selectedKey: day.id,
                onSelect: (id) {
                  if (id != widget.dayId) replaceWithDay(context, programId, id);
                },
                addTooltip: 'Add day',
                onAdd: () async {
                  final added = await showAddDayDialog(context, ref, programId: programId, week: week!);
                  if (!added || !context.mounted) return;
                  final updated = await ref.read(programDetailProvider(programId).future);
                  final days = updated.weeks.where((w) => w.id == week!.id).firstOrNull?.days ?? const [];
                  if (days.isNotEmpty && context.mounted) replaceWithDay(context, programId, days.last.id);
                },
              ),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text("Couldn't load the program. Try again.", style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
        data: (program) => day == null
            ? GoneState(message: 'This day no longer exists.', actionLabel: 'Back to the program', onAction: () => _leave(null))
            : _DayBody(
                program: program,
                day: day,
                scroll: _scroll,
                highlightedExerciseId: highlightedExerciseId,
                highlightKey: highlightKey,
                onAddExercise: () => _addExercise(day!),
              ),
      ),
    );
  }
}

class _DayBody extends ConsumerWidget {
  const _DayBody({
    required this.program,
    required this.day,
    required this.scroll,
    required this.highlightedExerciseId,
    required this.highlightKey,
    required this.onAddExercise,
  });

  final Program program;
  final ProgramDay day;
  final ScrollController scroll;
  final String? highlightedExerciseId;
  final GlobalKey highlightKey;
  final VoidCallback onAddExercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final notifier = ref.read(programDetailProvider(program.id).notifier);
    final exercises = day.exercises;

    if (day.isRestDay) {
      return ListView(
        padding: contentPadding(context, bottom: 32),
        children: [
          Text('Rest day', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Nothing is programmed. To add exercises, make it a training day from the ⋯ menu.',
            style: tokens.bodySmall,
          ),
        ],
      );
    }

    return ListView(
      controller: scroll,
      padding: contentPadding(context, bottom: 32),
      children: [
        Text(
          exercises.isEmpty ? 'No exercises yet.' : '${daySummary(day)} · drag to reorder',
          style: tokens.bodySmall.copyWith(color: tokens.fg3),
        ),
        const SizedBox(height: 8),
        if (exercises.isNotEmpty)
          Material(
            color: palette.bg1,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
              side: BorderSide(color: palette.borderSubtle),
            ),
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: exercises.length,
              itemBuilder: (context, i) {
                final e = exercises[i];
                return _ExerciseRow(
                  key: ValueKey(e.id),
                  rowKey: e.id == highlightedExerciseId ? highlightKey : null,
                  index: i,
                  exercise: e,
                  highlighted: e.id == highlightedExerciseId,
                  onTap: () => showExerciseEditSheet(context, programId: program.id, exerciseId: e.id),
                );
              },
              onReorderItem: (oldIndex, newIndex) {
                final ids = exercises.map((e) => e.id).toList();
                final moved = ids.removeAt(oldIndex);
                ids.insert(newIndex, moved);
                notifier.reorderExercises(dayId: day.id, orderedExerciseIds: ids);
              },
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('edit_day_add_exercise'),
          style: tokens.secondaryButtonStyle,
          onPressed: onAddExercise,
          icon: const Icon(Icons.add),
          label: const Text('Add exercise'),
        ),
      ],
    );
  }
}

/// An exercise in the day: a drag handle, its order, name, sets and notes,
/// and its load on the right. Tapping it opens the exercise sheet.
class _ExerciseRow extends ConsumerWidget {
  const _ExerciseRow({
    super.key,
    required this.rowKey,
    required this.index,
    required this.exercise,
    required this.highlighted,
    required this.onTap,
  });

  final GlobalKey? rowKey;
  final int index;
  final ProgramExercise exercise;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final theme = Theme.of(context);
    final unit = ref.watch(unitPreferenceProvider);
    final load = exerciseLoadSummary(exercise, unit);
    final notes = exercise.notes?.trim();

    return Semantics(
      container: true,
      button: true,
      child: Material(
        key: rowKey,
        color: highlighted ? palette.primarySubtle : palette.bg1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: index == 0 ? null : Border(top: BorderSide(color: palette.borderSubtle)),
          ),
          child: InkWell(
            key: ValueKey('edit_exercise_row_${exercise.id}'),
            onTap: onTap,
            hoverColor: palette.bg3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    // Hidden from screen readers: the list gives each row its own
                    // move up/down actions, and a label here would lead the row's.
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: 40,
                        height: 44,
                        child: Icon(Icons.drag_indicator, size: 20, color: tokens.fg3),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 20,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        '${index + 1}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: tokens.fg3,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(exercise.exerciseName, style: theme.textTheme.titleSmall),
                          Text(exerciseSetsSummary(exercise), style: tokens.bodySmall),
                          if (notes != null && notes.isNotEmpty)
                            Text(
                              notes,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tokens.bodySmall.copyWith(color: tokens.fg3),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (load != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 11, left: 8),
                      child: Text(load, style: tokens.weight),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Icon(Icons.chevron_right, size: 20, color: tokens.fg3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
