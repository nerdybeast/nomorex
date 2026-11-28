import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../exercises/widgets/exercise_picker_sheet.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/copy_errors.dart';
import '../../../shared/widgets/auto_save_field.dart';
import '../../../shared/widgets/toggle_card.dart';
import '../../ai/utils/suggest_text.dart';
import '../../ai/widgets/suggest_button.dart';
import '../providers/workout_detail_provider.dart';
import '../providers/workouts_provider.dart';
import '../utils/can_archive_workout.dart';
import '../widgets/exercise_editor_card.dart';
import '../widgets/set_editor.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/load_failure.dart';

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
      body: detail.whenLoaded(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LoadFailureView(
          title: "Couldn't load this workout",
          retrying: detail.retrying,
          onRetry: () => ref.invalidate(workoutDetailProvider(workoutId)),
        ),
        data: (workout) {
          final notifier = ref.read(workoutDetailProvider(workoutId).notifier);
          return CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: contentPadding(context),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    AutoSaveField(
                      initialValue: workout.title,
                      labelText: 'Title (e.g. Day 1)',
                      suffixBuilder: workoutSuggestSuffix(SuggestField.title, workout, unit, noun: 'title'),
                      onChanged: (v) {
                        final trimmed = v.trim();
                        if (trimmed.isNotEmpty) notifier.updateTitle(trimmed);
                      },
                    ),
                    const SizedBox(height: 16),
                    AutoSaveField(
                      initialValue: workout.notes,
                      labelText: 'Description',
                      maxLines: 3,
                      suffixBuilder: workoutSuggestSuffix(SuggestField.description, workout, unit, noun: 'description'),
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
                  // The same centered column as the fields above, so the cards
                  // line up with them and a set's load stays near its
                  // prescription on a wide screen.
                  padding: contentPadding(context, top: 0, bottom: 0),
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
                              onAddPercentageSets: (parsed) =>
                                  notifier.addPercentageSets(ex.id, parsed),
                              onAddAbsoluteSets: (batch) =>
                                  notifier.addAbsoluteSets(ex.id, batch),
                              onReplaceGroup: notifier.replaceSetGroup,
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
                padding: contentPadding(context, top: 0, bottom: 24),
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
