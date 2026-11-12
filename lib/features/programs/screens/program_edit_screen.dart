import 'package:flutter/material.dart';
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
import '../models/program_week.dart';
import '../providers/program_detail_provider.dart';
import '../utils/parsed_program_set.dart';
import '../../../core/utils/sequential_naming.dart';
import '../../../shared/widgets/responsive_layout.dart';

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

  /// Opens the exercise picker for [dayId]. A pick saves straight away; once
  /// the sheet closes, the new card is scrolled to and edged in orange.
  Future<void> _addExercise(String dayId) async {
    final provider = programDetailProvider(programId);
    List<ProgramExercise> dayExercises(Program p) =>
        p.weeks.expand((w) => w.days).firstWhere((d) => d.id == dayId).exercises;
    final before = dayExercises(await ref.read(provider.future));
    if (!mounted) return;
    final beforeIds = {for (final e in before) e.id};
    final added = await showExercisePickerSheet(
      context,
      addedExerciseIds: {for (final e in before) e.exerciseId},
      onPick: (exercise) => ref.read(provider.notifier).addExercise(dayId, exercise.id),
    );
    if (added == null || !mounted) return;
    final after = dayExercises(await ref.read(provider.future));
    final newRow = after.where((e) => !beforeIds.contains(e.id) && e.exerciseId == added.id).lastOrNull;
    if (newRow != null) highlightAddedExercise(newRow.id);
  }

  Future<void> _addDay(BuildContext context, WidgetRef ref, ProgramWeek week) async {
    final defaultTitle = nextSequentialName(week.days.map((d) => d.title), 'Day');
    final controller = TextEditingController();
    var isRestDay = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add day'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Title', hintText: defaultTitle),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Rest day'),
                value: isRestDay,
                onChanged: (v) => setState(() => isRestDay = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (result == true) {
      final typed = controller.text.trim();
      await ref.read(programDetailProvider(programId).notifier).addDay(
            week.id,
            title: typed.isEmpty ? defaultTitle : typed,
            isRestDay: isRestDay,
          );
    }
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
              _AutoSaveField(
                initialValue: program.name,
                labelText: 'Name',
                onChanged: (v) {
                  final trimmed = v.trim();
                  if (trimmed.isNotEmpty) notifier.updateProgramMeta(name: trimmed);
                },
              ),
              const SizedBox(height: 16),
              _AutoSaveField(
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
                    onAddDay: (week) => _addDay(context, ref, week),
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
  final void Function(String dayId) onAddExercise;
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
        subtitle: Text('${week.days.length} ${week.days.length == 1 ? 'day' : 'days'}'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: _AutoSaveField(
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
                TextButton.icon(
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
  final void Function(String dayId) onAddExercise;
  final String? highlightedExerciseId;
  final GlobalKey highlightKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(programDetailProvider(programId).notifier);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ExpansionTile(
        title: Text(day.title),
        subtitle: Text(day.isRestDay ? 'Rest day' : '${day.exercises.length} exercises'),
        children: [
          if (!day.isRestDay)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: day.exercises.length,
                itemBuilder: (context, i) {
                  final ex = day.exercises[i];
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
                        _AutoSaveField(
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
                          onDeleteSet: notifier.deleteSet,
                          onReorderSets: (orderedIds) =>
                              notifier.reorderSets(ex.id, orderedIds),
                        ),
                      ],
                    ),
                  );
                },
                onReorderItem: (oldIndex, newIndex) {
                  final ids = day.exercises.map((e) => e.id).toList();
                  final moved = ids.removeAt(oldIndex);
                  ids.insert(newIndex, moved);
                  notifier.reorderExercises(dayId: day.id, orderedExerciseIds: ids);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                if (!day.isRestDay)
                  TextButton.icon(
                    onPressed: () => onAddExercise(day.id),
                    icon: const Icon(Icons.add),
                    label: const Text('Exercise'),
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

// Tabbing or clicking away doesn't fire onFieldSubmitted (that only fires on
// Enter/"done"), so a typed value would otherwise be silently dropped —
// commit on blur too, same pattern as edit_workout_screen's _AutoSaveField.
class _AutoSaveField extends StatefulWidget {
  const _AutoSaveField({
    super.key,
    required this.initialValue,
    required this.labelText,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String? initialValue;
  final String labelText;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<_AutoSaveField> createState() => _AutoSaveFieldState();
}

class _AutoSaveFieldState extends State<_AutoSaveField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  final _focusNode = FocusNode();
  late String _lastCommitted = widget.initialValue ?? '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(_AutoSaveField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue ?? '';
      _lastCommitted = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    if (_controller.text == _lastCommitted) return;
    _lastCommitted = _controller.text;
    widget.onChanged(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: widget.labelText),
      onFieldSubmitted: (_) => _commit(),
    );
  }
}
