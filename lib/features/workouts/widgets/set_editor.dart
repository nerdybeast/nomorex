import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/percent_range.dart';
import '../../../core/utils/rep_range.dart';
import '../../../core/utils/rpe.dart';
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
  /// [repsMax] is the top of a rep range, or null for a single rep count.
  final void Function(AbsoluteSetBatch batch) onAddAbsoluteSets;
  final void Function(String setId) onDeleteSet;
  final void Function(List<String> orderedSetIds) onReorderSets;

  Future<void> _showPercentageSetDialog(
    BuildContext context,
    List<Exercise> exercises,
  ) async {
    var sets = 1;
    var reps = 1;
    int? repsMax;
    var percentage = 70.0;
    double? percentageMax;
    double? rpeMin;
    double? rpeMax;
    Exercise? basisExercise;
    final tokens = Theme.of(context).extension<NomorexTokens>();

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
                  onChanged: (v) => setState(() => sets = v.round()),
                  valueTextStyle: tokens?.stepperValue,
                  valueDecoration: tokens?.stepperValueDecoration,
                  decrementButtonStyle: tokens?.stepperDecrementStyle,
                  incrementButtonStyle: tokens?.stepperIncrementStyle,
                ),
                const SizedBox(height: 12),
                _repTargetInput(
                  reps: reps,
                  repsMax: repsMax,
                  tokens: tokens,
                  onChanged: (r, max) => setState(() {
                    reps = r;
                    repsMax = max;
                  }),
                ),
                const SizedBox(height: 12),
                // One %1RM (or range) shared by the whole batch keeps the
                // dialog a fixed height; wave-loading is another batch at the
                // next percentage. One decimal so half-percent prescriptions
                // like 72.5% can be typed; the +/- step stays 5.
                _RangeInput(
                  value: percentage,
                  max: percentageMax,
                  label: '%1RM',
                  minLabel: 'Min %1RM',
                  maxLabel: 'Max %1RM',
                  switchLabel: '%1RM range',
                  // The database accepts above 0 and up to 200% (#36), the
                  // same bounds an AI import accepts.
                  floor: kMinSetPercentage,
                  ceiling: kMaxSetPercentage,
                  step: 5,
                  decimals: 1,
                  spread: 5,
                  valueKey: const Key('set_editor_pct'),
                  switchKey: const Key('set_editor_pct_range_switch'),
                  maxKey: const Key('set_editor_pct_max'),
                  tokens: tokens,
                  onChanged: (v, max) => setState(() {
                    percentage = v;
                    percentageMax = max;
                  }),
                ),
                const SizedBox(height: 12),
                _RpeTargetInput(
                  rpeMin: rpeMin,
                  rpeMax: rpeMax,
                  tokens: tokens,
                  onChanged: (min, max) => setState(() {
                    rpeMin = min;
                    rpeMax = max;
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                onAddPercentageSets([
                  for (var i = 0; i < sets; i++)
                    ParsedSet(
                      reps,
                      percentage,
                      basisExerciseId: basisExercise?.id,
                      targetRepsMax: _rangeTop(reps, repsMax),
                      percentageMax: _rangeTop(percentage, percentageMax),
                      rpeMin: rpeMin,
                      rpeMax: rpeMin == null ? null : _rangeTop(rpeMin!, rpeMax),
                    ),
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
    int? repsMax;
    var weightDisplay = 0.0;
    var openLoad = false;
    double? rpeMin;
    double? rpeMax;
    var dialogUnit = unit == 'both' ? 'kg' : unit;
    final tokens = Theme.of(context).extension<NomorexTokens>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add sets (weight)'),
          content: SingleChildScrollView(
            child: Column(
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
                _repTargetInput(
                  reps: reps,
                  repsMax: repsMax,
                  tokens: tokens,
                  onChanged: (r, max) => setState(() {
                    reps = r;
                    repsMax = max;
                  }),
                ),
                // "Vert Pull 3x7-9, %1RM NA": no prescribed load, the lifter
                // picks it on the day. Hides the weight rather than saving
                // a misleading 0 kg.
                SwitchListTile(
                  key: const Key('set_editor_open_load_switch'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('No set load'),
                  subtitle: const Text('The lifter picks the weight'),
                  value: openLoad,
                  onChanged: (on) => setState(() => openLoad = on),
                ),
                if (!openLoad) ...[
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
                const SizedBox(height: 12),
                _RpeTargetInput(
                  rpeMin: rpeMin,
                  rpeMax: rpeMax,
                  tokens: tokens,
                  onChanged: (min, max) => setState(() {
                    rpeMin = min;
                    rpeMax = max;
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final weightKg = openLoad
                    ? null
                    : (dialogUnit == 'lbs' ? lbsToKg(weightDisplay) : weightDisplay);
                onAddAbsoluteSets(AbsoluteSetBatch(
                  sets: sets,
                  reps: reps,
                  repsMax: _rangeTop(reps, repsMax),
                  weightKg: weightKg,
                  rpeMin: rpeMin,
                  rpeMax: rpeMin == null ? null : _rangeTop(rpeMin!, rpeMax),
                ));
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
        ? formatPercentTarget(set.percentage, set.percentageMax)
        : isOpenLoad(set.weightMode)
            ? 'Choose load'
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
          Text(formatTargetReps(set.targetReps, set.targetRepsMax)),
        ],
      ),
      title: Text([
        isPct ? '$valueLabel of $basisLabel' : valueLabel,
        ?formatRpeTarget(set.rpeMin, set.rpeMax),
      ].join(' · ')),
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
    final tokens = theme.extension<NomorexTokens>();
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
          color: oneRepMax.isEstimated ? tokens?.info : null,
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

/// The range top to save: null unless it's actually above [low], so a range
/// the author narrowed back down to one number is stored as a single value.
T? _rangeTop<T extends num>(T low, T? high) =>
    (high != null && high > low) ? high : null;

/// A stepper plus an optional range switch that reveals a second stepper for
/// the top of the range ("7 to 9" reps, "67–72.5%"). With the switch off the
/// dialog keeps its original height; [max] is null exactly when it's off.
class _RangeInput extends StatelessWidget {
  const _RangeInput({
    required this.value,
    required this.max,
    required this.label,
    required this.minLabel,
    required this.maxLabel,
    required this.switchLabel,
    required this.floor,
    this.ceiling,
    required this.step,
    required this.decimals,
    required this.spread,
    required this.valueKey,
    required this.switchKey,
    required this.maxKey,
    required this.tokens,
    required this.onChanged,
  });

  final double value;
  final double? max;
  /// Stepper labels: [label] alone, [minLabel] / [maxLabel] as a range.
  final String label;
  final String minLabel;
  final String maxLabel;
  final String switchLabel;
  final double floor;
  final double? ceiling;
  final double step;
  final int decimals;
  /// How far above [value] the top starts when the switch is turned on.
  final double spread;
  final Key valueKey;
  final Key switchKey;
  final Key maxKey;
  final NomorexTokens? tokens;
  final void Function(double value, double? max) onChanged;

  @override
  Widget build(BuildContext context) {
    final top = max;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        NumberStepperField(
          key: valueKey,
          label: top == null ? label : minLabel,
          value: value,
          min: floor,
          max: ceiling,
          step: step,
          decimals: decimals,
          // Raising the bottom of a range past its top drags the top along,
          // so the pair can never be saved inverted.
          onChanged: (v) => onChanged(v, top == null ? null : (top < v ? v : top)),
          valueTextStyle: tokens?.stepperValue,
          valueDecoration: tokens?.stepperValueDecoration,
          decrementButtonStyle: tokens?.stepperDecrementStyle,
          incrementButtonStyle: tokens?.stepperIncrementStyle,
        ),
        SwitchListTile(
          key: switchKey,
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(switchLabel),
          value: top != null,
          // The top starts [spread] above the bottom, never past [ceiling].
          onChanged: (on) {
            final c = ceiling;
            final start = c != null && value + spread > c ? c : value + spread;
            onChanged(value, on ? start : null);
          },
        ),
        if (top != null)
          NumberStepperField(
            key: maxKey,
            label: maxLabel,
            value: top,
            min: value,
            max: ceiling,
            step: step,
            decimals: decimals,
            onChanged: (v) => onChanged(value, v),
            valueTextStyle: tokens?.stepperValue,
            valueDecoration: tokens?.stepperValueDecoration,
            decrementButtonStyle: tokens?.stepperDecrementStyle,
            incrementButtonStyle: tokens?.stepperIncrementStyle,
          ),
      ],
    );
  }
}

/// [_RangeInput] for a rep target: whole numbers from 1, starting a typical
/// two-rep spread ("7 to 9").
Widget _repTargetInput({
  required int reps,
  required int? repsMax,
  required NomorexTokens? tokens,
  required void Function(int reps, int? repsMax) onChanged,
}) =>
    _RangeInput(
      value: reps.toDouble(),
      max: repsMax?.toDouble(),
      label: 'Reps',
      minLabel: 'Min reps',
      maxLabel: 'Max reps',
      switchLabel: 'Rep range',
      floor: 1,
      step: 1,
      decimals: 0,
      spread: 2,
      valueKey: const Key('set_editor_reps'),
      switchKey: const Key('set_editor_rep_range_switch'),
      maxKey: const Key('set_editor_reps_max'),
      tokens: tokens,
      onChanged: (v, max) => onChanged(v.round(), max?.round()),
    );

/// Optional target effort for a batch: a "Target RPE" switch that reveals an
/// RPE stepper (1–10 in half steps, starting at 7) with its own range switch
/// ("RPE 6–7"). [rpeMin] is null exactly when no RPE is prescribed.
class _RpeTargetInput extends StatelessWidget {
  const _RpeTargetInput({
    required this.rpeMin,
    required this.rpeMax,
    required this.tokens,
    required this.onChanged,
  });

  final double? rpeMin;
  final double? rpeMax;
  final NomorexTokens? tokens;
  final void Function(double? rpeMin, double? rpeMax) onChanged;

  @override
  Widget build(BuildContext context) {
    final min = rpeMin;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          key: const Key('set_editor_rpe_switch'),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('Target RPE'),
          value: min != null,
          onChanged: (on) => onChanged(on ? 7 : null, null),
        ),
        if (min != null)
          _RangeInput(
            value: min,
            max: rpeMax,
            label: 'RPE',
            minLabel: 'Min RPE',
            maxLabel: 'Max RPE',
            switchLabel: 'RPE range',
            floor: kRpeMin,
            ceiling: kRpeMax,
            step: kRpeStep,
            decimals: 1,
            spread: 1,
            valueKey: const Key('set_editor_rpe'),
            switchKey: const Key('set_editor_rpe_range_switch'),
            maxKey: const Key('set_editor_rpe_max'),
            tokens: tokens,
            onChanged: onChanged,
          ),
      ],
    );
  }
}
