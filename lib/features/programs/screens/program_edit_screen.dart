import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../exercises/widgets/exercise_picker.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../shared/widgets/toggle_card.dart';
import '../../workouts/utils/parsed_set.dart';
import '../../workouts/widgets/set_editor.dart';
import '../models/program_day.dart';
import '../models/program_week.dart';
import '../providers/program_detail_provider.dart';
import '../utils/parsed_program_set.dart';

// SetEditor is shared with the workouts feature, so its "Add sets (%)"
// callback speaks ParsedSet regardless of caller; convert 1:1 to this
// feature's ParsedProgramSet before handing it to ProgramDetailNotifier.
ParsedProgramSet _toParsedProgramSet(ParsedSet p) =>
    ParsedProgramSet(p.targetReps, p.percentage, p.basisExerciseId);

class ProgramEditScreen extends ConsumerWidget {
  const ProgramEditScreen({super.key, required this.programId});
  final String programId;

  Future<void> _addExercise(BuildContext context, WidgetRef ref, String dayId) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add exercise'),
        content: SizedBox(
          width: 320,
          child: Consumer(
            builder: (context, ref, _) {
              final exercisesAsync = ref.watch(exercisesProvider);
              return exercisesAsync.when(
                loading: () => const SizedBox(
                  height: 72,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => SizedBox(
                  height: 72,
                  child: Center(child: Text('Could not load exercises: $e')),
                ),
                data: (exercises) => ExercisePicker(
                  exercises: exercises,
                  selected: null,
                  onSelected: (ex) async {
                    Navigator.pop(ctx);
                    await ref
                        .read(programDetailProvider(programId).notifier)
                        .addExercise(dayId, ex.id);
                  },
                  onAddCustom: (name) async {
                    final newEx =
                        await ref.read(exercisesProvider.notifier).addCustomExercise(name);
                    if (ctx.mounted) Navigator.pop(ctx);
                    await ref
                        .read(programDetailProvider(programId).notifier)
                        .addExercise(dayId, newEx.id);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _addDay(BuildContext context, WidgetRef ref, String weekId) async {
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
                decoration: const InputDecoration(labelText: 'Title (e.g. Day 1)'),
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
    if (result == true && controller.text.trim().isNotEmpty) {
      await ref.read(programDetailProvider(programId).notifier).addDay(
            weekId,
            title: controller.text.trim(),
            isRestDay: isRestDay,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(programDetailProvider(programId));
    final unit = ref.watch(unitPreferenceProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EDIT PROGRAM'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'editProgramFab',
        onPressed: () => ref.read(programDetailProvider(programId).notifier).addWeek(),
        icon: const Icon(Icons.add),
        label: const Text('Week'),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (program) {
          final notifier = ref.read(programDetailProvider(programId).notifier);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                subtitle: 'Other users can view this program',
                value: program.isPublic,
                onChanged: (v) => notifier.updateVisibility(v),
              ),
              const Divider(height: 32),
              if (program.weeks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No weeks yet. Tap "Week" to add one.')),
                )
              else
                for (final week in program.weeks)
                  _WeekCard(
                    key: ValueKey(week.id),
                    programId: programId,
                    week: week,
                    unit: unit,
                    onAddDay: (weekId) => _addDay(context, ref, weekId),
                    onAddExercise: (dayId) => _addExercise(context, ref, dayId),
                  ),
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
  });

  final String programId;
  final ProgramWeek week;
  final String unit;
  final void Function(String weekId) onAddDay;
  final void Function(String dayId) onAddExercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(programDetailProvider(programId).notifier);
    return Card(
      child: ExpansionTile(
        title: Text('Week ${week.weekNumber}${week.label != null ? ' — ${week.label}' : ''}'),
        subtitle: Text('${week.days.length} ${week.days.length == 1 ? 'day' : 'days'}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => notifier.removeWeek(week.id),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
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
            ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => onAddDay(week.id),
                icon: const Icon(Icons.add),
                label: const Text('Day'),
              ),
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
  });

  final String programId;
  final ProgramDay day;
  final String unit;
  final void Function(String dayId) onAddExercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(programDetailProvider(programId).notifier);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ExpansionTile(
        title: Text(day.title),
        subtitle: Text(day.isRestDay ? 'Rest day' : '${day.exercises.length} exercises'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => notifier.removeDay(day.id),
        ),
        children: [
          if (!day.isRestDay)
            for (final ex in day.exercises)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(ex.exerciseName,
                                  style: Theme.of(context).textTheme.titleMedium),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => notifier.removeExercise(ex.id),
                            ),
                          ],
                        ),
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
                          onAddPercentageSets: (parsed) => notifier.addPercentageSets(
                            ex.id,
                            [
                              for (final p in parsed)
                                _toParsedProgramSet(p),
                            ],
                          ),
                          onAddAbsoluteSets: (sets, reps, weightKg) => notifier
                              .addAbsoluteSets(ex.id, sets: sets, reps: reps, weightKg: weightKg),
                          onDeleteSet: notifier.deleteSet,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          if (!day.isRestDay)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => onAddExercise(day.id),
                  icon: const Icon(Icons.add),
                  label: const Text('Exercise'),
                ),
              ),
            ),
        ],
      ),
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
