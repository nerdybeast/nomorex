import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dark_theme.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/models/editable_set_row.dart';
import '../../../shared/widgets/number_stepper_field.dart';
import '../../exercises/models/exercise.dart';
import '../../exercises/providers/exercises_provider.dart';
import '../utils/parsed_set.dart';

/// Editable list of sets for a single exercise, plus add controls. Works
/// against [EditableSetRow] rather than a concrete `WorkoutSet`/`ProgramSet`
/// so it's shared between editing a logged workout and authoring a program.
class SetEditor extends ConsumerWidget {
  const SetEditor({
    super.key,
    required this.sets,
    required this.unit,
    required this.onAddPercentageSets,
    required this.onAddAbsoluteSets,
    required this.onDeleteSet,
  });

  final List<EditableSetRow> sets;
  final String unit;
  final void Function(List<ParsedSet>) onAddPercentageSets;
  final void Function(int sets, int reps, double weightKg) onAddAbsoluteSets;
  final void Function(String setId) onDeleteSet;

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
    var dialogUnit = unit;
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
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'kg', label: Text('kg')),
                      ButtonSegment(value: 'lbs', label: Text('lbs')),
                    ],
                    selected: {dialogUnit},
                    onSelectionChanged: (selection) => setState(() {
                      final newUnit = selection.first;
                      if (newUnit == dialogUnit) return;
                      weightDisplay = newUnit == 'lbs'
                          ? kgToLbs(weightDisplay)
                          : lbsToKg(weightDisplay);
                      dialogUnit = newUnit;
                    }),
                    style: const ButtonStyle(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
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
        for (final s in sets)
          _SetRow(
            set: s,
            onDelete: () => onDeleteSet(s.id),
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
    required this.set,
    required this.onDelete,
  });

  final EditableSetRow set;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isPct = set.weightMode == 'percentage';
    final valueLabel = isPct
        ? '${set.percentage?.toStringAsFixed(0) ?? '?'}%'
        : (set.absoluteWeightKg != null
            ? formatWeightBoth(set.absoluteWeightKg!)
            : '? lbs / ? kg');
    final basisLabel = set.basisExerciseId != null
        ? (set.basisExerciseName ?? '1RM')
        : '1RM';
    return ListTile(
      dense: true,
      leading: Text('${set.targetReps ?? '-'} reps'),
      title: Text(isPct ? '$valueLabel of $basisLabel' : valueLabel),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onDelete,
      ),
    );
  }
}
