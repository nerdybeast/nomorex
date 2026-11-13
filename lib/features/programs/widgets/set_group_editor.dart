import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/percent_range.dart';
import '../../../core/utils/rpe.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/models/one_rep_max.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../exercises/models/exercise.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../../workouts/providers/one_rep_max_provider.dart';
import '../../workouts/utils/parsed_set.dart';
import '../../workouts/utils/set_resolver.dart';
import '../../workouts/widgets/set_editor.dart';
import '../models/program_exercise.dart';
import '../providers/program_detail_provider.dart';
import '../screens/edit/widgets/edit_chrome.dart';
import '../utils/parsed_program_set.dart';
import '../utils/program_day_brief.dart';

/// A program exercise's sets as groups of identical consecutive sets: "10 ×
/// 1 · 80% of 1RM" is one row, not ten. Tapping a group opens the sets sheet
/// filled in, and saving rewrites the whole group in one call
/// (`replace_program_set_group`). Its ⋯ menu edits just the last set (how a
/// single set comes to differ: a group split into identical sets would read
/// as one group again) or deletes the group. Groups drag to reorder.
class SetGroupEditor extends ConsumerStatefulWidget {
  const SetGroupEditor({super.key, required this.programId, required this.exercise, required this.unit});

  final String programId;
  final ProgramExercise exercise;

  /// The user's unit preference ('kg', 'lbs' or 'both').
  final String unit;

  @override
  ConsumerState<SetGroupEditor> createState() => _SetGroupEditorState();
}

class _SetGroupEditorState extends ConsumerState<SetGroupEditor> {
  /// The groups' first-set ids in a just-dropped order, shown until the save
  /// comes back so the list doesn't snap back meanwhile.
  List<String>? _pendingOrder;

  ProgramDetailNotifier get _notifier => ref.read(programDetailProvider(widget.programId).notifier);
  ProgramExercise get _exercise => widget.exercise;

  void _failed() {
    if (mounted) showEditSnack(context, "Couldn't save the sets. Try again.");
  }

  Future<void> _replace(List<String> ids, int count, Map<String, Object?> prescription) async {
    try {
      await _notifier.replaceSetGroup(ids, count, prescription);
    } catch (_) {
      _failed();
    }
  }

  /// Opens the sets sheet for [group], or for its last set alone.
  Future<void> _edit(SetGroup group, {bool lastOnly = false}) async {
    final first = group.first;
    final ids = lastOnly ? [group.sets.last.id] : [for (final s in group.sets) s.id];
    final initial = SetsSheetInitial(
      sets: lastOnly ? 1 : group.count,
      reps: first.targetReps ?? 1,
      repsMax: first.targetRepsMax,
      percentage: first.percentage,
      percentageMax: first.percentageMax,
      weightKg: first.absoluteWeightKg,
      basisExerciseId: first.basisExerciseId,
      basisExerciseName: first.basisExerciseName,
      rpeMin: first.rpeMin,
      rpeMax: first.rpeMax,
    );
    if (first.weightMode == 'percentage') {
      final exercises = ref.read(exercisesProvider).asData?.value ?? const <Exercise>[];
      await showPercentageSetsSheet(
        context,
        exercises: exercises,
        currentExerciseId: _exercise.exerciseId,
        currentExerciseName: _exercise.exerciseName,
        unit: widget.unit,
        initial: initial,
        onSubmit: (sets) {
          final p = sets.first;
          _replace(ids, sets.length, {
            'target_reps': p.targetReps,
            'target_reps_max': p.targetRepsMax,
            'weight_mode': 'percentage',
            'percentage': p.percentage,
            'percentage_max': p.percentageMax,
            'basis_exercise_id': p.basisExerciseId,
            'rpe_min': p.rpeMin,
            'rpe_max': p.rpeMax,
            'note': first.note,
          });
        },
      );
    } else {
      await showAbsoluteSetsSheet(
        context,
        currentExerciseName: _exercise.exerciseName,
        unit: widget.unit,
        initial: initial,
        onSubmit: (batch) => _replace(ids, batch.sets, {
          'target_reps': batch.reps,
          'target_reps_max': batch.repsMax,
          'weight_mode': batch.weightKg == null ? 'open' : 'absolute',
          'absolute_weight_kg': batch.weightKg,
          'rpe_min': batch.rpeMin,
          'rpe_max': batch.rpeMax,
          'note': first.note,
        }),
      );
    }
  }

  Future<void> _delete(SetGroup group) async {
    if (group.count > 1) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Delete ${group.count} sets?',
        message: '${setGroupLabel(group)} of ${_exercise.exerciseName} will be removed.',
        confirmLabel: 'Delete',
      );
      if (!confirmed) return;
    }
    await _replace([for (final s in group.sets) s.id], 0, const {});
  }

  Future<void> _showActions(SetGroup group) async {
    final action = await showActionSheet<String>(
      context,
      title: '${setGroupLabel(group)} · ${_exercise.exerciseName}',
      actions: [
        const SheetAction('edit', 'Edit sets', Icons.edit_outlined),
        if (group.count > 1) const SheetAction('last', 'Edit the last set only', Icons.vertical_align_bottom),
        SheetAction('delete', group.count == 1 ? 'Delete set' : 'Delete ${group.count} sets', Icons.delete_outline, danger: true),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'edit':
        await _edit(group);
      case 'last':
        await _edit(group, lastOnly: true);
      case 'delete':
        await _delete(group);
    }
  }

  Future<void> _reorder(List<SetGroup> groups, int oldIndex, int newIndex) async {
    final order = [...groups];
    final moved = order.removeAt(oldIndex);
    order.insert(newIndex, moved);
    setState(() => _pendingOrder = [for (final g in order) g.first.id]);
    try {
      await _notifier.reorderSets(_exercise.id, [for (final g in order) ...g.sets.map((s) => s.id)]);
    } catch (_) {
      _failed();
    } finally {
      if (mounted) setState(() => _pendingOrder = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final byId = ref.watch(oneRepMaxProvider).asData?.value ?? const <String, OneRepMax>{};
    final byName = ref.watch(oneRepMaxByNameProvider).asData?.value ?? const <String, OneRepMax>{};
    final exercises = ref.watch(exercisesProvider).asData?.value ?? const <Exercise>[];

    var groups = groupConsecutiveSets(_exercise.sets);
    final pending = _pendingOrder;
    if (pending != null) {
      final byFirst = {for (final g in groups) g.first.id: g};
      if (pending.length == byFirst.length && pending.every(byFirst.containsKey)) {
        groups = [for (final id in pending) byFirst[id]!];
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No sets yet.', style: tokens.bodySmall.copyWith(color: tokens.fg3)),
          )
        else
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
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final group = groups[i];
                final set = group.first;
                final oneRepMax = set.weightMode == 'percentage'
                    ? lookupOneRepMax(
                        basisExerciseId: set.basisExerciseId ?? _exercise.exerciseId,
                        basisExerciseName: set.basisExerciseName ?? _exercise.exerciseName,
                        byExerciseId: byId,
                        byExerciseName: byName,
                      )
                    : null;
                return _GroupRow(
                  key: ValueKey(set.id),
                  index: i,
                  group: group,
                  exercise: _exercise,
                  unit: widget.unit,
                  oneRepMax: oneRepMax,
                  onTap: () => _edit(group),
                  onMore: () => _showActions(group),
                );
              },
              onReorderItem: (oldIndex, newIndex) => _reorder(groups, oldIndex, newIndex),
            ),
          ),
        const SizedBox(height: 12),
        // Side by side: two equal actions, and the sheet stays short.
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('set_groups_add_pct'),
                style: tokens.secondaryButtonStyle,
                onPressed: () => showPercentageSetsSheet(
                  context,
                  exercises: exercises,
                  currentExerciseId: _exercise.exerciseId,
                  currentExerciseName: _exercise.exerciseName,
                  unit: widget.unit,
                  onSubmit: (parsed) => _notifier
                      .addPercentageSets(_exercise.id, [for (final p in parsed) _toParsedProgramSet(p)])
                      .catchError((_) => _failed()),
                ),
                icon: const Icon(Icons.percent, size: 18),
                label: const Text('Add % sets'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                key: const Key('set_groups_add_weight'),
                style: tokens.secondaryButtonStyle,
                onPressed: () => showAbsoluteSetsSheet(
                  context,
                  currentExerciseName: _exercise.exerciseName,
                  unit: widget.unit,
                  onSubmit: (batch) => _notifier.addAbsoluteSets(_exercise.id, batch).catchError((_) => _failed()),
                ),
                icon: const Icon(Icons.fitness_center, size: 18),
                label: const Text('Add weight sets'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One group: a drag handle, "10 × 1" over its prescription ("80% of 1RM ·
/// RPE 7"), the load it resolves to in blue when there's a 1RM, and ⋯.
class _GroupRow extends StatelessWidget {
  const _GroupRow({
    super.key,
    required this.index,
    required this.group,
    required this.exercise,
    required this.unit,
    required this.oneRepMax,
    required this.onTap,
    required this.onMore,
  });

  final int index;
  final SetGroup group;
  final ProgramExercise exercise;
  final String unit;
  final OneRepMax? oneRepMax;
  final VoidCallback onTap;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final theme = Theme.of(context);
    final set = group.first;
    final isPct = set.weightMode == 'percentage';
    final isOpen = isOpenLoad(set.weightMode);

    final String load;
    if (isPct) {
      final basis = set.basisExerciseId != null &&
              set.basisExerciseName != null &&
              set.basisExerciseName!.toLowerCase() != exercise.exerciseName.toLowerCase()
          ? set.basisExerciseName!
          : '1RM';
      load = '${formatPercentTarget(set.percentage, set.percentageMax)} of $basis';
    } else if (isOpen || set.absoluteWeightKg == null) {
      load = kOpenLoadLabel;
    } else {
      load = formatWeightForPreference(set.absoluteWeightKg!, unit);
    }
    final rpe = formatRpeTarget(set.rpeMin, set.rpeMax);
    final range = isPct && oneRepMax != null
        ? resolveSetWeightRangeKg(
            weightMode: set.weightMode,
            percentage: set.percentage,
            percentageMax: set.percentageMax,
            oneRepMaxKg: oneRepMax!.kg,
          )
        : null;

    return Semantics(
      container: true,
      button: true,
      child: Material(
        color: palette.bg1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: index == 0 ? null : Border(top: BorderSide(color: palette.borderSubtle)),
          ),
          child: InkWell(
            key: ValueKey('set_group_${set.id}'),
            onTap: onTap,
            hoverColor: palette.bg3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
              child: Row(
                children: [
                  ReorderableDragStartListener(
                    index: index,
                    // Hidden from screen readers: the list gives each group
                    // move up/down actions of its own.
                    child: ExcludeSemantics(
                      child: SizedBox(
                        width: 36,
                        height: 48,
                        child: Icon(Icons.drag_indicator, size: 20, color: tokens.fg3),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            setGroupLabel(group),
                            style: theme.textTheme.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                          Text(
                            [load, ?rpe].join(' · '),
                            style: isPct || isOpen
                                ? tokens.bodySmall.copyWith(color: isOpen ? tokens.fg3 : null)
                                : tokens.weight.copyWith(color: palette.fg2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (range != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        formatResolvedWeightRange(range.low, range.high, unit, estimated: oneRepMax!.isEstimated),
                        style: tokens.weight.copyWith(color: palette.info),
                      ),
                    ),
                  IconButton(
                    key: ValueKey('set_group_more_${set.id}'),
                    tooltip: '${setGroupLabel(group)} options',
                    icon: const Icon(Icons.more_horiz),
                    onPressed: onMore,
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

// The sets sheet speaks the workouts feature's ParsedSet; programs store a
// ParsedProgramSet. Same fields, one to one.
ParsedProgramSet _toParsedProgramSet(ParsedSet p) => ParsedProgramSet(
      p.targetReps,
      p.percentage,
      basisExerciseId: p.basisExerciseId,
      targetRepsMax: p.targetRepsMax,
      percentageMax: p.percentageMax,
      rpeMin: p.rpeMin,
      rpeMax: p.rpeMax,
    );
