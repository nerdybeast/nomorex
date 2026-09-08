import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dark_theme.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/models/editable_set_row.dart';
import '../../../shared/widgets/number_stepper_field.dart';
import '../../../shared/widgets/unit_toggle.dart';
import '../../../shared/models/one_rep_max.dart';
import '../../exercises/models/exercise.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../providers/one_rep_max_provider.dart';
import '../utils/parsed_set.dart';
import '../utils/set_resolver.dart';

/// Editable list of sets for a single exercise, plus add controls. Works
/// against [EditableSetRow] rather than a concrete `WorkoutSet`/`ProgramSet`
/// so it's shared between editing a logged workout and authoring a program.
class SetEditor extends ConsumerWidget {
  const SetEditor({
    super.key,
    required this.sets,
    required this.unit,
    required this.currentExerciseId,
    required this.currentExerciseName,
    required this.onAddPercentageSets,
    required this.onAddAbsoluteSets,
    required this.onDeleteSet,
    required this.onReorderSets,
  });

  final List<EditableSetRow> sets;
  /// The user's unit preference ('kg', 'lbs', or 'both').
  final String unit;

  /// The exercise these sets belong to — the basis a percentage set resolves
  /// against when the "Based on" dropdown is left on "This exercise".
  final String currentExerciseId;
  final String currentExerciseName;
  final void Function(List<ParsedSet>) onAddPercentageSets;
  final void Function(int sets, int reps, double weightKg) onAddAbsoluteSets;
  final void Function(String setId) onDeleteSet;
  final void Function(List<String> orderedSetIds) onReorderSets;

  Future<void> _showPercentageSetDialog(
    BuildContext context,
    List<Exercise> exercises,
  ) async {
    var sets = 1;
    var reps = 1;
    var percentages = <double>[70];
    Exercise? basisExercise;
    final tokens = Theme.of(context).extension<NomorexDarkTokens>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add sets (%)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Exercise?>(
                  initialValue: basisExercise,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Based on'),
                  items: [
                    const DropdownMenuItem<Exercise?>(
                      child: Text('This exercise', overflow: TextOverflow.ellipsis),
                    ),
                    for (final ex in exercises)
                      DropdownMenuItem<Exercise?>(
                        value: ex,
                        child: Text(ex.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => basisExercise = v),
                ),
                const SizedBox(height: 8),
                _BasisOneRepMax(
                  basisExerciseId: basisExercise?.id ?? currentExerciseId,
                  basisExerciseName: basisExercise?.name ?? currentExerciseName,
                  unit: unit,
                ),
                const SizedBox(height: 12),
                NumberStepperField(
                  label: 'Sets',
                  value: sets.toDouble(),
                  min: 1,
                  step: 1,
                  decimals: 0,
                  onChanged: (v) => setState(() {
                    final newSets = v.round();
                    if (newSets > percentages.length) {
                      percentages = [
                        ...percentages,
                        for (var i = percentages.length; i < newSets; i++)
                          percentages.last,
                      ];
                    } else if (newSets < percentages.length) {
                      percentages = percentages.sublist(0, newSets);
                    }
                    sets = newSets;
                  }),
                  valueTextStyle: tokens?.stepperValue,
                  valueDecoration: tokens?.stepperValueDecoration,
                  decrementButtonStyle: tokens?.stepperDecrementStyle,
                  incrementButtonStyle: tokens?.stepperIncrementStyle,
                ),
                const SizedBox(height: 12),
                NumberStepperField(
                  label: 'Reps',
                  value: reps.toDouble(),
                  min: 1,
                  step: 1,
                  decimals: 0,
                  onChanged: (v) => setState(() => reps = v.round()),
                  valueTextStyle: tokens?.stepperValue,
                  valueDecoration: tokens?.stepperValueDecoration,
                  decrementButtonStyle: tokens?.stepperDecrementStyle,
                  incrementButtonStyle: tokens?.stepperIncrementStyle,
                ),
                const SizedBox(height: 12),
                // One stepper per set (rather than a single shared value) so
                // wave-loading (a different %1RM per set) stays possible.
                for (var i = 0; i < percentages.length; i++)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
                    child: NumberStepperField(
                      label: 'Set ${i + 1} %1RM',
                      value: percentages[i],
                      min: 0,
                      step: 5,
                      decimals: 0,
                      onChanged: (v) => setState(() => percentages[i] = v),
                      valueTextStyle: tokens?.stepperValue,
                      valueDecoration: tokens?.stepperValueDecoration,
                      decrementButtonStyle: tokens?.stepperDecrementStyle,
                      incrementButtonStyle: tokens?.stepperIncrementStyle,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                onAddPercentageSets([
                  for (final p in percentages) ParsedSet(reps, p, basisExercise?.id),
                ]);
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAbsoluteSetDialog(BuildContext context) async {
    var sets = 1;
    var reps = 1;
    var weightDisplay = 0.0;
    var dialogUnit = unit == 'both' ? 'kg' : unit;
    final tokens = Theme.of(context).extension<NomorexDarkTokens>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add sets (weight)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NumberStepperField(
                label: 'Sets',
                value: sets.toDouble(),
                min: 1,
                step: 1,
                decimals: 0,
                onChanged: (v) => setState(() => sets = v.round()),
                valueTextStyle: tokens?.stepperValue,
                valueDecoration: tokens?.stepperValueDecoration,
                decrementButtonStyle: tokens?.stepperDecrementStyle,
                incrementButtonStyle: tokens?.stepperIncrementStyle,
              ),
              const SizedBox(height: 12),
              NumberStepperField(
                label: 'Reps',
                value: reps.toDouble(),
                min: 1,
                step: 1,
                decimals: 0,
                onChanged: (v) => setState(() => reps = v.round()),
                valueTextStyle: tokens?.stepperValue,
                valueDecoration: tokens?.stepperValueDecoration,
                decrementButtonStyle: tokens?.stepperDecrementStyle,
                incrementButtonStyle: tokens?.stepperIncrementStyle,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Expanded(child: Text('Unit')),
                  UnitToggle(
                    preference: unit,
                    value: dialogUnit,
                    onChanged: (newUnit) => setState(() {
                      if (newUnit == dialogUnit) return;
                      weightDisplay = newUnit == 'lbs'
                          ? kgToLbs(weightDisplay)
                          : lbsToKg(weightDisplay);
                      dialogUnit = newUnit;
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              NumberStepperField(
                label: 'Weight ($dialogUnit)',
                value: weightDisplay,
                min: 0,
                step: dialogUnit == 'lbs' ? 5.0 : 2.5,
                decimals: 1,
                onChanged: (v) => setState(() => weightDisplay = v),
                valueTextStyle: tokens?.stepperValue,
                valueDecoration: tokens?.stepperValueDecoration,
                decrementButtonStyle: tokens?.stepperDecrementStyle,
                incrementButtonStyle: tokens?.stepperIncrementStyle,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final weightKg = dialogUnit == 'lbs' ? lbsToKg(weightDisplay) : weightDisplay;
                onAddAbsoluteSets(sets, reps, weightKg);
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exercisesProvider).asData?.value ?? const <Exercise>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: sets.length,
          onReorderItem: (oldIndex, newIndex) {
            final ids = sets.map((s) => s.id).toList();
            final moved = ids.removeAt(oldIndex);
            ids.insert(newIndex, moved);
            onReorderSets(ids);
          },
          itemBuilder: (context, i) => _SetRow(
            key: ValueKey(sets[i].id),
            index: i,
            set: sets[i],
            unit: unit,
            onDelete: () => onDeleteSet(sets[i].id),
          ),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _showPercentageSetDialog(context, exercises),
              icon: const Icon(Icons.add),
              label: const Text('Add sets (%)'),
            ),
            TextButton.icon(
              onPressed: () => _showAbsoluteSetDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add sets (weight)'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.unit,
    required this.onDelete,
  });

  final int index;
  final EditableSetRow set;
  final String unit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isPct = set.weightMode == 'percentage';
    final valueLabel = isPct
        ? '${set.percentage?.toStringAsFixed(0) ?? '?'}%'
        : (set.absoluteWeightKg != null
            ? formatWeightForPreference(set.absoluteWeightKg!, unit)
            : (unit == 'both' ? '? lbs / ? kg' : '? $unit'));
    final basisLabel = set.basisExerciseId != null
        ? (set.basisExerciseName ?? '1RM')
        : '1RM';
    return ListTile(
      dense: true,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          const SizedBox(width: 8),
          Text('${set.targetReps ?? '-'} reps'),
        ],
      ),
      title: Text(isPct ? '$valueLabel of $basisLabel' : valueLabel),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onDelete,
      ),
    );
  }
}

/// The 1RM the percentages in the "Add sets (%)" dialog will resolve against.
///
/// Watches the 1RM providers rather than reading them in the dialog's
/// callback: they're `keepAlive` but still lazy, so nothing would have loaded
/// them if no screen behind the dialog happened to be watching, and `.asData`
/// would read as "no 1RM" instead of "not loaded yet".
///
/// Deliberately not a [SetPrLink] in the empty case — navigating off to the
/// add-PR screen would discard the half-filled dialog.
class _BasisOneRepMax extends ConsumerWidget {
  const _BasisOneRepMax({
    required this.basisExerciseId,
    required this.basisExerciseName,
    required this.unit,
  });

  final String basisExerciseId;
  final String basisExerciseName;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = theme.extension<NomorexDarkTokens>();
    final byId = ref.watch(oneRepMaxProvider).asData?.value ??
        const <String, OneRepMax>{};
    final byName = ref.watch(oneRepMaxByNameProvider).asData?.value ??
        const <String, OneRepMax>{};

    final oneRepMax = lookupOneRepMax(
      basisExerciseId: basisExerciseId,
      basisExerciseName: basisExerciseName,
      byExerciseId: byId,
      byExerciseName: byName,
    );

    final Widget label;
    if (oneRepMax == null) {
      label = Text(
        'No 1RM recorded for this lift',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    } else {
      final weight = formatWeightForPreference(oneRepMax.kg, unit);
      label = Text(
        oneRepMax.isEstimated ? 'Est. 1RM $weight' : '1RM $weight',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: oneRepMax.isEstimated ? tokens?.secondaryAccent : null,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: label,
      ),
    );
  }
}
