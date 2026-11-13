import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/auto_save_field.dart';
import '../../../../../shared/widgets/confirm_dialog.dart';
import '../../../../profile/providers/profile_provider.dart';
import '../../../models/program_exercise.dart';
import '../../../providers/program_detail_provider.dart';
import '../../../widgets/set_group_editor.dart';

/// Edits one exercise of a program day in a sheet over the day: its notes
/// and its sets as groups ([SetGroupEditor]), or delete it. Stays in step
/// with the saved program, and closes itself if the exercise goes away.
Future<void> showExerciseEditSheet(
  BuildContext context, {
  required String programId,
  required String exerciseId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => _ExerciseEditSheet(programId: programId, exerciseId: exerciseId),
  );
}

class _ExerciseEditSheet extends ConsumerWidget {
  const _ExerciseEditSheet({required this.programId, required this.exerciseId});

  final String programId;
  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programDetailProvider(programId)).asData?.value;
    final unit = ref.watch(unitPreferenceProvider);
    final tokens = NomorexTokens.of(context);
    final theme = Theme.of(context);

    ProgramExercise? exercise;
    String? where;
    if (program != null) {
      for (final week in program.weeks) {
        for (final day in week.days) {
          final i = day.exercises.indexWhere((e) => e.id == exerciseId);
          if (i >= 0) {
            exercise = day.exercises[i];
            where = '${day.title} · exercise ${i + 1}';
          }
        }
      }
    }
    if (exercise == null) {
      // Deleted here or elsewhere: there's nothing left to edit.
      if (program != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).maybePop();
        });
      }
      return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
    }
    final ex = exercise;
    final notifier = ref.read(programDetailProvider(programId).notifier);

    Future<void> delete() async {
      if (ex.sets.isNotEmpty) {
        final confirmed = await showConfirmDialog(
          context,
          title: 'Delete ${ex.exerciseName}?',
          message: 'This will also delete its ${ex.sets.length} ${ex.sets.length == 1 ? 'set' : 'sets'}.',
          confirmLabel: 'Delete',
        );
        if (!confirmed) return;
      }
      await notifier.removeExercise(ex.id);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(where!, style: tokens.bodySmall.copyWith(color: tokens.fg3)),
                          Text(ex.exerciseName, style: theme.textTheme.titleLarge),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('edit_exercise_delete'),
                      tooltip: 'Delete ${ex.exerciseName}',
                      color: tokens.palette.dangerText,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: delete,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AutoSaveField(
                  key: ValueKey('notes_${ex.id}'),
                  initialValue: ex.notes,
                  labelText: 'Notes (e.g. build to a heavy triple)',
                  onChanged: (v) => notifier.updateExerciseNotes(ex.id, v),
                ),
                const SizedBox(height: 12),
                SetGroupEditor(programId: programId, exercise: ex, unit: unit),
              ],
            ),
          ),
          // Pinned under the list, so Done is in reach however many sets.
          DecoratedBox(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: tokens.palette.borderSubtle))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('edit_exercise_done'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
