import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../exercises/widgets/exercise_picker.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../shared/widgets/toggle_card.dart';
import '../providers/workout_detail_provider.dart';
import '../widgets/set_editor.dart';

class EditWorkoutScreen extends ConsumerWidget {
  const EditWorkoutScreen({super.key, required this.workoutId});
  final String workoutId;

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add exercise'),
        content: SizedBox(
          width: 320,
          // Watch the exercises reactively: the list is often still loading
          // when this dialog opens, and RawAutocomplete shows no options (not
          // even "Add custom") for an empty list. A Consumer rebuilds the
          // picker once the exercises arrive.
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
                        .read(workoutDetailProvider(workoutId).notifier)
                        .addExercise(ex.id);
                  },
                  onAddCustom: (name) async {
                    final newEx = await ref
                        .read(exercisesProvider.notifier)
                        .addCustomExercise(name);
                    if (ctx.mounted) Navigator.pop(ctx);
                    await ref
                        .read(workoutDetailProvider(workoutId).notifier)
                        .addExercise(newEx.id);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(workoutDetailProvider(workoutId));
    final unit = ref.watch(unitPreferenceProvider);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EDIT WORKOUT'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'editWorkoutFab',
        onPressed: () => _addExercise(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Exercise'),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (workout) {
          final notifier = ref.read(workoutDetailProvider(workoutId).notifier);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AutoSaveField(
                initialValue: workout.title,
                labelText: 'Title (e.g. Day 1)',
                onChanged: (v) {
                  final trimmed = v.trim();
                  if (trimmed.isNotEmpty) notifier.updateTitle(trimmed);
                },
              ),
              const SizedBox(height: 16),
              _AutoSaveField(
                initialValue: workout.notes,
                labelText: 'Description',
                maxLines: 3,
                onChanged: notifier.updateDescription,
              ),
              const SizedBox(height: 16),
              ToggleCard(
                title: 'Public',
                subtitle: 'Other users can view this workout',
                value: workout.isPublic,
                onChanged: (v) => notifier.updateVisibility(v),
              ),
              const Divider(height: 32),
              if (workout.exercises.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No exercises yet. Tap "Exercise" to add one.')),
                )
              else
                for (final ex in workout.exercises)
                  Card(
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
                            onAddPercentageSets: (parsed) =>
                                notifier.addPercentageSets(ex.id, parsed),
                            onAddAbsoluteSets: (sets, reps, weightKg) =>
                                notifier.addAbsoluteSets(ex.id,
                                    sets: sets, reps: reps, weightKg: weightKg),
                            onDeleteSet: notifier.deleteSet,
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

// Tabbing or clicking away doesn't fire onFieldSubmitted (that only fires on
// Enter/"done"), so a typed value would otherwise be silently dropped —
// commit on blur too, same pattern as SetEditor's _NumberField.
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
