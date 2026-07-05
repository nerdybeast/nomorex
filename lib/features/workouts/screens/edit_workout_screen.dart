import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../exercises/widgets/exercise_picker.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/workouts_provider.dart';
import '../providers/workout_detail_provider.dart';
import '../widgets/set_editor.dart';

class EditWorkoutScreen extends ConsumerStatefulWidget {
  const EditWorkoutScreen({super.key, required this.workoutId});
  final String? workoutId;

  @override
  ConsumerState<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends ConsumerState<EditWorkoutScreen> {
  final _titleController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _workoutId; // becomes non-null once created
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _workoutId = widget.workoutId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _createThenEdit() async {
    if (_titleController.text.trim().isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    setState(() { _creating = true; _error = null; });
    try {
      final id = await ref.read(workoutsProvider.notifier).createWorkout(
            title: _titleController.text.trim(),
            date: _date,
          );
      setState(() => _workoutId = id);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Phase 1: no workout yet -> title + date form.
    if (_workoutId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Workout')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title (e.g. Day 1)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(formatDate(_date)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _creating ? null : _createThenEdit,
                  child: _creating
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create & add exercises'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Phase 2: edit exercises/sets of the created/existing workout.
    return _ExerciseEditor(workoutId: _workoutId!);
  }
}

class _ExerciseEditor extends ConsumerWidget {
  const _ExerciseEditor({required this.workoutId});
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Workout'),
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
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workout) {
          if (workout.exercises.isEmpty) {
            return const Center(child: Text('No exercises yet. Tap "Exercise" to add one.'));
          }
          final notifier = ref.read(workoutDetailProvider(workoutId).notifier);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                        TextFormField(
                          initialValue: ex.notes,
                          decoration: const InputDecoration(
                            labelText: 'Notes (e.g. build to a heavy triple)',
                            border: OutlineInputBorder(),
                          ),
                          onFieldSubmitted: (v) => notifier.updateExerciseNotes(ex.id, v),
                        ),
                        const SizedBox(height: 8),
                        SetEditor(
                          exercise: ex,
                          unit: unit,
                          onAddPercentageSets: (parsed) =>
                              notifier.addPercentageSets(ex.id, parsed),
                          onAddAbsoluteSet: () => notifier.addAbsoluteSet(ex.id),
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
