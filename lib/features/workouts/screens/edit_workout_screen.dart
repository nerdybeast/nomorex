import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../exercises/widgets/exercise_picker_sheet.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/copy_errors.dart';
import '../../../shared/widgets/toggle_card.dart';
import '../providers/workout_detail_provider.dart';
import '../providers/workouts_provider.dart';
import '../utils/can_archive_workout.dart';
import '../widgets/exercise_editor_card.dart';
import '../widgets/set_editor.dart';
import '../../../shared/widgets/responsive_layout.dart';

class EditWorkoutScreen extends ConsumerStatefulWidget {
  const EditWorkoutScreen({super.key, required this.workoutId});
  final String workoutId;

  @override
  ConsumerState<EditWorkoutScreen> createState() => _EditWorkoutScreenState();
}

class _EditWorkoutScreenState extends ConsumerState<EditWorkoutScreen>
    with JustAddedExerciseHighlight {
  final _scroll = ScrollController();

  String get workoutId => widget.workoutId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Opens the exercise picker. A pick saves straight away; once the sheet
  /// closes, the new card is scrolled to and edged in orange for a moment.
  Future<void> _addExercise() async {
    final provider = workoutDetailProvider(workoutId);
    final before = (await ref.read(provider.future)).exercises;
    if (!mounted) return;
    final beforeIds = {for (final e in before) e.id};
    final added = await showExercisePickerSheet(
      context,
      addedExerciseIds: {for (final e in before) e.exerciseId},
      onPick: (exercise) => ref.read(provider.notifier).addExercise(exercise.id),
    );
    if (added == null || !mounted) return;
    final after = (await ref.read(provider.future)).exercises;
    final newRow = after.where((e) => !beforeIds.contains(e.id) && e.exerciseId == added.id).lastOrNull;
    if (newRow != null) highlightAddedExercise(newRow.id, scrollController: _scroll);
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(workoutDetailProvider(workoutId));
    final unit = ref.watch(unitPreferenceProvider);
    final workoutForArchive = detail.asData?.value;
    final showArchiveIcon = workoutForArchive != null && canArchiveWorkout(workoutForArchive);

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit workout'),
        actions: [
          if (showArchiveIcon)
            IconButton(
              key: const Key('edit_workout_archive'),
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archive',
              onPressed: () async {
                await ref.read(workoutsProvider.notifier).archiveWorkout(workoutForArchive);
                if (context.mounted) context.go(AppConstants.routeWorkouts);
              },
            ),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
        data: (workout) {
          final notifier = ref.read(workoutDetailProvider(workoutId).notifier);
          return CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: contentPadding(context),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
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
                      subtitle: workout.isImported
                          ? kImportNotShareableMessage
                          : workout.isCopy
                          ? kCopyNotShareableMessage
                          : 'Other users can view this workout',
                      value: workout.isPublic,
                      // Copies can't be published — the database rejects it too.
                      onChanged: workout.isCopy ? null : (v) => notifier.updateVisibility(v),
                    ),
                    const Divider(height: 32),
                    if (workout.exercises.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: Text('No exercises yet. Tap "Add exercise" to add one.')),
                      ),
                  ]),
                ),
              ),
              if (workout.exercises.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverReorderableList(
                    itemCount: workout.exercises.length,
                    itemBuilder: (context, i) {
                      final ex = workout.exercises[i];
                      return Padding(
                        key: ValueKey(ex.id),
                        padding: const EdgeInsets.only(bottom: 16),
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
                              onAddPercentageSets: (parsed) =>
                                  notifier.addPercentageSets(ex.id, parsed),
                              onAddAbsoluteSets: (batch) =>
                                  notifier.addAbsoluteSets(ex.id, batch),
                              onDeleteSet: notifier.deleteSet,
                              onReorderSets: (orderedIds) =>
                                  notifier.reorderSets(ex.id, orderedIds),
                            ),
                          ],
                        ),
                      );
                    },
                    onReorderItem: (oldIndex, newIndex) {
                      final ids = workout.exercises.map((e) => e.id).toList();
                      final moved = ids.removeAt(oldIndex);
                      ids.insert(newIndex, moved);
                      notifier.reorderExercises(ids);
                    },
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: FilledButton.icon(
                    key: const Key('edit_workout_add_exercise'),
                    style: NomorexTokens.of(context).secondaryButtonStyle,
                    onPressed: _addExercise,
                    icon: const Icon(Icons.add),
                    label: const Text('Add exercise'),
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
