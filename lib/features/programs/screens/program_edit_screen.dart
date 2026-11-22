import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/copy_errors.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/copied_from_badge.dart';
import '../../exercises/widgets/exercise_picker_sheet.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../shared/widgets/toggle_card.dart';
import '../../workouts/utils/parsed_set.dart';
import '../../workouts/widgets/exercise_editor_card.dart';
import '../../workouts/widgets/set_editor.dart';
import '../models/program.dart';
import '../models/program_exercise.dart';
import '../models/program_day.dart';
import '../models/program_session.dart';
import '../models/program_week.dart';
import '../providers/program_detail_provider.dart';
import '../utils/parsed_program_set.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/auto_save_field.dart';
import '../widgets/add_day_dialog.dart';
import 'edit/program_edit_actions.dart';

// SetEditor is shared with the workouts feature, so its "Add sets (%)"
// callback speaks ParsedSet regardless of caller; convert 1:1 to this
// feature's ParsedProgramSet before handing it to ProgramDetailNotifier.
ParsedProgramSet _toParsedProgramSet(ParsedSet p) =>
    ParsedProgramSet(
      p.targetReps,
      p.percentage,
      basisExerciseId: p.basisExerciseId,
      targetRepsMax: p.targetRepsMax,
      percentageMax: p.percentageMax,
      rpeMin: p.rpeMin,
      rpeMax: p.rpeMax,
      setType: p.setType,
    );

class ProgramEditScreen extends ConsumerStatefulWidget {
  const ProgramEditScreen({super.key, required this.programId});
  final String programId;

  @override
  ConsumerState<ProgramEditScreen> createState() => _ProgramEditScreenState();
}

class _ProgramEditScreenState extends ConsumerState<ProgramEditScreen>
    with JustAddedExerciseHighlight {
  final _scroll = ScrollController();

  String get programId => widget.programId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Opens the exercise picker for [dayId]'s session [sessionId] (its first
  /// session when null). A pick saves straight away; once the sheet closes,
  /// the new card is scrolled to and edged in orange.
  Future<void> _addExercise(String dayId, [String? sessionId]) async {
    final provider = programDetailProvider(programId);
    List<ProgramExercise> dayExercises(Program p) =>
        p.weeks.expand((w) => w.days).firstWhere((d) => d.id == dayId).exercises;
    final before = dayExercises(await ref.read(provider.future));
    if (!mounted) return;
    final beforeIds = {for (final e in before) e.id};
    final added = await showExercisePickerSheet(
      context,
      addedExerciseIds: {
        for (final e in before)
          if (sessionId == null || e.programSessionId == sessionId) e.exerciseId,
      },
      onPick: (exercise) => ref.read(provider.notifier).addExercise(dayId, exercise.id, sessionId: sessionId),
    );
    if (added == null || !mounted) return;
    final after = dayExercises(await ref.read(provider.future));
    final newRow = after.where((e) => !beforeIds.contains(e.id) && e.exerciseId == added.id).lastOrNull;
    if (newRow != null) highlightAddedExercise(newRow.id);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(programDetailProvider(programId));
    final unit = ref.watch(unitPreferenceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit program'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (program) {
          final notifier = ref.read(programDetailProvider(programId).notifier);
          return ListView(
            controller: _scroll,
            padding: contentPadding(context),
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
                maxLines: 3,
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
              const Divider(height: 32),
              if (program.weeks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No weeks yet. Tap "Add week" to add one.')),
                )
              else
                for (final week in program.weeks)
                  _WeekCard(
                    key: ValueKey(week.id),
                    programId: programId,
                    week: week,
                    unit: unit,
                    onAddDay: (week) => showAddDayDialog(context, ref, programId: programId, week: week),
                    onAddExercise: _addExercise,
                    highlightedExerciseId: highlightedExerciseId,
                    highlightKey: highlightKey,
                  ),
              const SizedBox(height: 8),
              FilledButton.icon(
                key: const Key('edit_program_add_week'),
                style: NomorexTokens.of(context).secondaryButtonStyle,
                onPressed: () => notifier.addWeek(),
                icon: const Icon(Icons.add),
                label: const Text('Add week'),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _WeekCard extends ConsumerWidget {
  const _WeekCard({
    super.key,
    required this.programId,
    required this.week,
    required this.unit,
    required this.onAddDay,
    required this.onAddExercise,
    required this.highlightedExerciseId,
    required this.highlightKey,
  });

  final String programId;
  final ProgramWeek week;
  final String unit;
  final void Function(ProgramWeek week) onAddDay;
  final void Function(String dayId, [String? sessionId]) onAddExercise;
  final String? highlightedExerciseId;
  final GlobalKey highlightKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(programDetailProvider(programId).notifier);
    Future<void> deleteWeek() async {
      if (week.days.isEmpty) {
        await notifier.removeWeek(week.id);
        return;
      }
      final dayCount = week.days.length;
      final confirmed = await showConfirmDialog(
        context,
        title: 'Delete week?',
        message: 'This will also delete its $dayCount ${dayCount == 1 ? 'day' : 'days'}.',
        confirmLabel: 'Delete',
      );
      if (confirmed) {
        await notifier.removeWeek(week.id);
      }
    }

    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text('Week ${week.weekNumber}${week.label != null ? ' — ${week.label}' : ''}'),
        subtitle: Text('${week.days.length} of $kMaxDaysPerWeek days'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AutoSaveField(
              key: ValueKey('${week.id}-label'),
              initialValue: week.label,
              labelText: 'Label (e.g. Loading Week 2/6)',
              onChanged: (v) => notifier.updateWeekMeta(week.id, label: v),
            ),
          ),
          for (final day in week.days)
            _DayCard(
              key: ValueKey(day.id),
              programId: programId,
              day: day,
              unit: unit,
              onAddExercise: onAddExercise,
              highlightedExerciseId: highlightedExerciseId,
              highlightKey: highlightKey,
            ),
          // Delete lives in the expanded body rather than the header's
          // `trailing`: the header is a ListTile, which would merge the
          // button into its own semantics node.
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // A week holds at most 7 days; a full week offers none.
                if (!week.isFull)
                  TextButton.icon(
                    key: ValueKey('edit_program_add_day_${week.id}'),
                    onPressed: () => onAddDay(week),
                    icon: const Icon(Icons.add),
                    label: const Text('Day'),
                  ),
                const Spacer(),
                _DeleteTextButton(label: 'Delete week', onPressed: deleteWeek),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One day in the desktop editor: its exercises, grouped under a header per
/// session when it has more than one (up to [kMaxSessionsPerDay]).
class _DayCard extends ConsumerWidget {
  const _DayCard({
    super.key,
    required this.programId,
    required this.day,
    required this.unit,
    required this.onAddExercise,
    required this.highlightedExerciseId,
    required this.highlightKey,
  });

  final String programId;
  final ProgramDay day;
  final String unit;
  final void Function(String dayId, [String? sessionId]) onAddExercise;
  final String? highlightedExerciseId;
  final GlobalKey highlightKey;

  Widget _exerciseList(ProgramDetailNotifier notifier, List<ProgramExercise> exercises) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: exercises.length,
          itemBuilder: (context, i) {
            final ex = exercises[i];
            return Padding(
              key: ValueKey(ex.id),
              padding: const EdgeInsets.only(bottom: 12),
              child: ExerciseEditorCard(
                key: ex.id == highlightedExerciseId ? highlightKey : null,
                index: i,
                name: ex.exerciseName,
                highlighted: ex.id == highlightedExerciseId,
                onDelete: () => notifier.removeExercise(ex.id),
                children: [
                  AutoSaveField(
                    key: ValueKey(ex.id),
                    initialValue: ex.notes,
                    labelText: 'Notes (e.g. build to a heavy triple)',
                    onChanged: (v) => notifier.updateExerciseNotes(ex.id, v),
                  ),
                  const SizedBox(height: 8),
                  SetEditor(
                    sets: ex.sets.map((s) => s.toEditableRow()).toList(),
                    unit: unit,
                    currentExerciseId: ex.exerciseId,
                    currentExerciseName: ex.exerciseName,
                    onAddPercentageSets: (parsed) => notifier.addPercentageSets(
                      ex.id,
                      [
                        for (final p in parsed)
                          _toParsedProgramSet(p),
                      ],
                    ),
                    onAddAbsoluteSets: (batch) => notifier.addAbsoluteSets(ex.id, batch),
                    onReplaceGroup: notifier.replaceSetGroup,
                    onReorderSets: (orderedIds) =>
                        notifier.reorderSets(ex.id, orderedIds),
                  ),
                ],
              ),
            );
          },
          onReorderItem: (oldIndex, newIndex) {
            final ids = exercises.map((e) => e.id).toList();
            final moved = ids.removeAt(oldIndex);
            ids.insert(newIndex, moved);
            notifier.reorderExercises(dayId: day.id, orderedExerciseIds: ids);
          },
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(programDetailProvider(programId).notifier);
    final split = !day.isRestDay && day.hasMultipleSessions;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ExpansionTile(
        title: Text(day.title),
        subtitle: Text(day.isRestDay
            ? 'Rest day'
            : split
                ? '${day.sessions.length} sessions · ${day.exercises.length} exercises'
                : '${day.exercises.length} exercises'),
        children: [
          if (split)
            for (final (i, session) in day.sessions.indexed) ...[
              // The ⋯ sits beside the title in a Row, not in a ListTile's
              // trailing, so it stays its own button for screen readers.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(session.label(i), style: Theme.of(context).textTheme.titleSmall),
                      ),
                    ),
                    IconButton(
                      key: ValueKey('edit_session_more_${session.id}'),
                      tooltip: '${session.label(i)} options',
                      icon: const Icon(Icons.more_horiz),
                      onPressed: () => showSessionActions(context, ref, programId: programId, day: day, session: session),
                    ),
                  ],
                ),
              ),
              _exerciseList(notifier, session.exercises),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: ValueKey('edit_session_add_exercise_${session.id}'),
                    onPressed: () => onAddExercise(day.id, session.id),
                    icon: const Icon(Icons.add),
                    label: Text('Exercise to ${session.label(i)}'),
                  ),
                ),
              ),
            ]
          else if (!day.isRestDay)
            _exerciseList(notifier, day.exercises),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                // Offered on a rest day too: adding an exercise makes it a
                // training day (ProgramDetailNotifier.addExercise).
                if (!split)
                  TextButton.icon(
                    onPressed: () => onAddExercise(day.id),
                    icon: const Icon(Icons.add),
                    label: const Text('Exercise'),
                  ),
                if (!day.isRestDay && day.sessions.isNotEmpty && day.canAddSession)
                  TextButton.icon(
                    key: ValueKey('edit_day_add_session_${day.id}'),
                    onPressed: () => addSessionTo(context, ref, programId: programId, day: day),
                    icon: const Icon(Icons.add),
                    label: const Text('Session'),
                  ),
                const Spacer(),
                _DeleteTextButton(
                  label: 'Delete day',
                  onPressed: () async {
                    final count = day.exercises.length;
                    if (count > 0) {
                      final confirmed = await showConfirmDialog(
                        context,
                        title: 'Delete day?',
                        message: 'This will also delete its $count ${count == 1 ? 'exercise' : 'exercises'}.',
                        confirmLabel: 'Delete',
                      );
                      if (!confirmed) return;
                    }
                    await notifier.removeDay(day.id);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A destructive action in an expanded week or day: danger-text, so it reads
/// apart from the neutral "+ Day" / "+ Exercise" beside it.
class _DeleteTextButton extends StatelessWidget {
  const _DeleteTextButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final danger = NomorexTokens.of(context).palette.dangerText;
    return TextButton.icon(
      style: TextButton.styleFrom(foregroundColor: danger),
      onPressed: onPressed,
      icon: const Icon(Icons.delete_outline),
      label: Text(label),
    );
  }
}
