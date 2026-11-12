import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/percent_range.dart';
import '../../../core/utils/rep_range.dart';
import '../../../core/utils/rpe.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/models/editable_set_row.dart';
import '../../../shared/widgets/number_stepper_field.dart';
import '../../../shared/widgets/responsive_layout.dart';
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

    await _showSetsSheet(
      context,
      (ctx, setState) => _SetsSheet(
        title: 'Add sets · $currentExerciseName',
        sets: sets,
        preview: _PercentPreview(
          sets: sets,
          reps: reps,
          repsMax: repsMax,
          percentage: percentage,
          percentageMax: percentageMax,
          rpeMin: rpeMin,
          rpeMax: rpeMax,
          basisExerciseId: basisExercise?.id ?? currentExerciseId,
          basisExerciseName: basisExercise?.name ?? currentExerciseName,
          unit: unit,
        ),
        fields: [
          _BasisRow(
            exercises: exercises,
            value: basisExercise,
            currentExerciseName: currentExerciseName,
            basisExerciseId: basisExercise?.id ?? currentExerciseId,
            basisExerciseName: basisExercise?.name ?? currentExerciseName,
            unit: unit,
            onChanged: (v) => setState(() => basisExercise = v),
          ),
          _setsCountRow(sets: sets, onChanged: (v) => setState(() => sets = v)),
          _repTargetInput(
            reps: reps,
            repsMax: repsMax,
            onChanged: (r, max) => setState(() {
              reps = r;
              repsMax = max;
            }),
          ),
          // One %1RM (or range) shared by the whole batch keeps the sheet a
          // fixed height; wave-loading is another batch at the next
          // percentage. One decimal so half-percent prescriptions like 72.5%
          // can be typed; the +/- step stays 5.
          _RangeInput(
            value: percentage,
            max: percentageMax,
            label: '%1RM',
            minLabel: 'Min %1RM',
            maxLabel: 'Max %1RM',
            switchLabel: '%1RM range',
            // The database accepts above 0 and up to 200% (#36), the same
            // bounds an AI import accepts.
            floor: kMinSetPercentage,
            ceiling: kMaxSetPercentage,
            step: 5,
            decimals: 1,
            spread: 5,
            valueKey: const Key('set_editor_pct'),
            switchKey: const Key('set_editor_pct_range_switch'),
            maxKey: const Key('set_editor_pct_max'),
            onChanged: (v, max) => setState(() {
              percentage = v;
              percentageMax = max;
            }),
          ),
          _RpeTargetInput(
            rpeMin: rpeMin,
            rpeMax: rpeMax,
            onChanged: (min, max) => setState(() {
              rpeMin = min;
              rpeMax = max;
            }),
          ),
        ],
        onAdd: () {
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

    await _showSetsSheet(
      context,
      (ctx, setState) {
        final tokens = NomorexTokens.of(ctx);
        final weightLabel = 'Weight ($dialogUnit)';
        return _SetsSheet(
          title: 'Add sets · $currentExerciseName',
          sets: sets,
          preview: _Preview(
            line: _sentence(
              ctx,
              sets: sets,
              reps: reps,
              repsMax: repsMax,
              load: openLoad ? null : '${_trimNumber(weightDisplay)} $dialogUnit',
              loadIsMono: true,
              rpe: formatRpeTarget(rpeMin, rpeMax),
            ),
            detail: openLoad
                ? Text('The lifter picks the weight on the day', style: tokens.bodySmall)
                : null,
          ),
          fields: [
            _setsCountRow(sets: sets, onChanged: (v) => setState(() => sets = v)),
            _repTargetInput(
              reps: reps,
              repsMax: repsMax,
              onChanged: (r, max) => setState(() {
                reps = r;
                repsMax = max;
              }),
            ),
            // "Vert Pull 3x7-9, %1RM NA": no prescribed load, the lifter
            // picks it on the day. Hides the weight rather than saving a
            // misleading 0 kg.
            SwitchListTile(
              key: const Key('set_editor_open_load_switch'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('No set load'),
              subtitle: Text('The lifter picks the weight', style: tokens.bodySmall),
              value: openLoad,
              onChanged: (on) => setState(() => openLoad = on),
            ),
            if (!openLoad)
              _FieldRow(
                label: weightLabel,
                // Under the label rather than beside it: beside it, the
                // label, toggle and stepper don't fit a phone's row.
                below: UnitToggle(
                  preference: unit,
                  value: dialogUnit,
                  onChanged: (newUnit) => setState(() {
                    if (newUnit == dialogUnit) return;
                    weightDisplay = newUnit == 'lbs' ? kgToLbs(weightDisplay) : lbsToKg(weightDisplay);
                    dialogUnit = newUnit;
                  }),
                ),
                trailing: _compactStepper(
                  label: weightLabel,
                  value: weightDisplay,
                  min: 0,
                  step: dialogUnit == 'lbs' ? 5.0 : 2.5,
                  decimals: 1,
                  tokens: tokens,
                  onChanged: (v) => setState(() => weightDisplay = v),
                ),
              ),
            _RpeTargetInput(
              rpeMin: rpeMin,
              rpeMax: rpeMax,
              onChanged: (min, max) => setState(() {
                rpeMin = min;
                rpeMax = max;
              }),
            ),
          ],
          onAdd: () {
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercises = ref.watch(exercisesProvider).asData?.value ?? const <Exercise>[];
    final byId = ref.watch(oneRepMaxProvider).asData?.value ?? const <String, OneRepMax>{};
    final byName = ref.watch(oneRepMaxByNameProvider).asData?.value ?? const <String, OneRepMax>{};
    final tokens = NomorexTokens.of(context);
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
          itemBuilder: (context, i) {
            final set = sets[i];
            final oneRepMax = set.weightMode == 'percentage'
                ? lookupOneRepMax(
                    basisExerciseId: set.basisExerciseId ?? currentExerciseId,
                    basisExerciseName: set.basisExerciseName ?? currentExerciseName,
                    byExerciseId: byId,
                    byExerciseName: byName,
                  )
                : null;
            return _SetRow(
              key: ValueKey(set.id),
              index: i,
              set: set,
              unit: unit,
              oneRepMax: oneRepMax,
              onDelete: () => onDeleteSet(set.id),
            );
          },
        ),
        const SizedBox(height: 8),
        // Bordered secondary buttons rather than loose text links, so the
        // two ways to add sets read as actions. A Wrap, so a narrow card
        // stacks them instead of overflowing.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _AddSetsButton(
              label: 'Add sets (%)',
              icon: Icons.percent,
              tokens: tokens,
              onPressed: () => _showPercentageSetDialog(context, exercises),
            ),
            _AddSetsButton(
              label: 'Add sets (weight)',
              icon: Icons.fitness_center,
              tokens: tokens,
              onPressed: () => _showAbsoluteSetDialog(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddSetsButton extends StatelessWidget {
  const _AddSetsButton({
    required this.label,
    required this.icon,
    required this.tokens,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final NomorexTokens tokens;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: tokens.secondaryButtonStyle.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
        padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
        textStyle: WidgetStatePropertyAll(tokens.buttonSmall),
        // 36px to look at, 48px to hit.
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}

/// One prescribed set, read like a ledger line: reps, then the
/// prescription, then (for a percentage set the lifter has a 1RM for) the
/// load it resolves to, right-aligned in blue mono.
class _SetRow extends StatelessWidget {
  const _SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.unit,
    required this.oneRepMax,
    required this.onDelete,
  });

  final int index;
  final EditableSetRow set;
  final String unit;
  final OneRepMax? oneRepMax;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final body = Theme.of(context).textTheme.bodyMedium!;
    final isPct = set.weightMode == 'percentage';
    final isOpen = isOpenLoad(set.weightMode);
    final valueLabel = isPct
        ? formatPercentTarget(set.percentage, set.percentageMax)
        : isOpen
            ? 'Choose load'
            : (set.absoluteWeightKg != null
                ? formatWeightForPreference(set.absoluteWeightKg!, unit)
                : (unit == 'both' ? '? lbs / ? kg' : '? $unit'));
    final basisLabel = set.basisExerciseId != null
        ? (set.basisExerciseName ?? '1RM')
        : '1RM';
    final prescription = [
      isPct ? '$valueLabel of $basisLabel' : valueLabel,
      ?formatRpeTarget(set.rpeMin, set.rpeMax),
    ].join(' · ');
    final prescriptionStyle = isPct
        ? body.copyWith(color: palette.fg1)
        : isOpen
            ? body.copyWith(color: palette.fg3)
            : tokens.weight.copyWith(color: palette.fg1);

    final range = isPct && oneRepMax != null
        ? resolveSetWeightRangeKg(
            weightMode: set.weightMode,
            percentage: set.percentage,
            percentageMax: set.percentageMax,
            oneRepMaxKg: oneRepMax!.kg,
          )
        : null;

    // The remove button sits beside the row's content rather than inside a
    // ListTile: a tile merges its children into one semantics node, so a
    // button inside it couldn't be activated on its own by assistive tech.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: 'Drag to reorder',
              child: SizedBox(
                width: 28,
                height: 40,
                child: Icon(Icons.drag_handle, size: 18, color: palette.fg3),
              ),
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(
              formatTargetReps(set.targetReps, set.targetRepsMax),
              style: body.copyWith(
                color: palette.fg2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(child: Text(prescription, style: prescriptionStyle)),
          if (range != null) ...[
            const SizedBox(width: 8),
            Text(
              formatResolvedWeightRange(range.low, range.high, unit, estimated: oneRepMax!.isEstimated),
              key: ValueKey('set_editor_resolved_${set.id}'),
              style: tokens.weight.copyWith(color: palette.info),
            ),
          ],
          IconButton(
            tooltip: 'Remove set',
            icon: Icon(Icons.close, size: 18, color: palette.fg3),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Opens an "Add sets" sheet: a bottom sheet on a phone, a centered panel
/// on a wider screen. [builder] rebuilds through a [StatefulBuilder] as the
/// steppers change, so the preview reads back every tap.
Future<void> _showSetsSheet(
  BuildContext context,
  Widget Function(BuildContext ctx, StateSetter setState) builder,
) {
  Widget content() => StatefulBuilder(builder: builder);
  if (isMobile(context)) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Keeps the Add button above the keyboard while a value is typed.
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: content(),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: content(),
      ),
    ),
  );
}

/// The "Add sets" layout: a title, a live preview of what will be added,
/// the fields as hairline-divided rows, and Cancel / "Add 3 sets" pinned at
/// the bottom on the floor color.
class _SetsSheet extends StatelessWidget {
  const _SetsSheet({
    required this.title,
    required this.sets,
    required this.preview,
    required this.fields,
    required this.onAdd,
  });

  final String title;
  final int sets;
  final Widget preview;
  final List<Widget> fields;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    // A bottom sheet draws its own drag handle above this; a dialog doesn't.
    final inSheet = isMobile(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, inSheet ? 0 : 12, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close, color: palette.fg2),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                preview,
                const SizedBox(height: 4),
                for (var i = 0; i < fields.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: palette.borderSubtle),
                  fields[i],
                ],
              ],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.bg0,
            border: Border(top: BorderSide(color: palette.borderSubtle)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, inSheet ? 16 : 12),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: tokens.secondaryButtonStyle,
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const Key('set_editor_add'),
                    onPressed: onAdd,
                    child: Text('Add $sets ${sets == 1 ? 'set' : 'sets'}'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The batch read back the way a coach writes it, on a `bg-1` card.
class _Preview extends StatelessWidget {
  const _Preview({required this.line, this.detail});

  final InlineSpan line;
  final Widget? detail;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    return Container(
      key: const Key('set_editor_preview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: palette.bg1,
        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
        border: Border.all(color: palette.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(line),
          if (detail != null) ...[const SizedBox(height: 6), detail!],
        ],
      ),
    );
  }
}

/// "8–10" or "5": reps on their own, for "3 × 8–10".
String _repsText(int reps, int? repsMax) =>
    repsMax == null || repsMax <= reps ? '$reps' : '$reps–$repsMax';

/// "100" or "102.5": a stepper value without a trailing ".0".
String _trimNumber(double v) {
  final text = v.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

/// "3 × 8–10 @ 70–75% · RPE 7": the count and reps in `fg-1`, the load in
/// orange ink, the RPE in `fg-2`. A null [load] reads "· choose load".
TextSpan _sentence(
  BuildContext context, {
  required int sets,
  required int reps,
  required int? repsMax,
  required String? load,
  bool loadIsMono = false,
  String? rpe,
}) {
  final tokens = NomorexTokens.of(context);
  final palette = tokens.palette;
  final base = Theme.of(context).textTheme.titleLarge!.copyWith(
        fontSize: 20,
        height: 26 / 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: palette.fg1,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
  return TextSpan(
    style: base,
    children: [
      TextSpan(text: '$sets × ${_repsText(reps, repsMax)}'),
      if (load == null)
        TextSpan(text: ' · choose load', style: base.copyWith(color: palette.fg3, fontWeight: FontWeight.w500))
      else
        TextSpan(
          style: base.copyWith(color: palette.primaryText),
          children: [
            const TextSpan(text: ' @ '),
            TextSpan(
              text: load,
              style: loadIsMono ? tokens.weightLg.copyWith(color: palette.primaryText) : null,
            ),
          ],
        ),
      if (rpe != null)
        TextSpan(text: ' · $rpe', style: base.copyWith(color: palette.fg2, fontWeight: FontWeight.w500)),
    ],
  );
}

/// The basis lift's 1RM for the viewer, id first then name (see
/// [lookupOneRepMax]). Watched rather than read in a callback: the providers
/// are `keepAlive` but lazy, so `.asData` would read "no 1RM" before they
/// load.
OneRepMax? _watchOneRepMax(WidgetRef ref, String basisExerciseId, String basisExerciseName) {
  final byId = ref.watch(oneRepMaxProvider).asData?.value ?? const <String, OneRepMax>{};
  final byName = ref.watch(oneRepMaxByNameProvider).asData?.value ?? const <String, OneRepMax>{};
  return lookupOneRepMax(
    basisExerciseId: basisExerciseId,
    basisExerciseName: basisExerciseName,
    byExerciseId: byId,
    byExerciseName: byName,
  );
}

/// The %1RM preview: the sentence, then the load it resolves to in blue
/// mono, or that there's no 1RM to resolve against.
class _PercentPreview extends ConsumerWidget {
  const _PercentPreview({
    required this.sets,
    required this.reps,
    required this.repsMax,
    required this.percentage,
    required this.percentageMax,
    required this.rpeMin,
    required this.rpeMax,
    required this.basisExerciseId,
    required this.basisExerciseName,
    required this.unit,
  });

  final int sets;
  final int reps;
  final int? repsMax;
  final double percentage;
  final double? percentageMax;
  final double? rpeMin;
  final double? rpeMax;
  final String basisExerciseId;
  final String basisExerciseName;
  final String unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final oneRepMax = _watchOneRepMax(ref, basisExerciseId, basisExerciseName);
    final top = percentageMax != null && percentageMax! > percentage ? percentageMax : null;

    final Widget detail;
    if (oneRepMax == null) {
      detail = Text(
        'No 1RM recorded for this lift',
        style: tokens.bodySmall.copyWith(color: palette.fg3),
      );
    } else {
      final range = resolveSetWeightRangeKg(
        weightMode: 'percentage',
        percentage: percentage,
        percentageMax: top,
        oneRepMaxKg: oneRepMax.kg,
      )!;
      detail = Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        children: [
          Text(
            formatResolvedWeightRange(range.low, range.high, unit, estimated: oneRepMax.isEstimated),
            key: const Key('set_editor_preview_load'),
            style: tokens.weightLg.copyWith(color: palette.info),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text('each set', style: tokens.bodySmall),
          ),
        ],
      );
    }

    return _Preview(
      line: _sentence(
        context,
        sets: sets,
        reps: reps,
        repsMax: repsMax,
        load: formatPercentTarget(percentage, top),
        rpe: formatRpeTarget(rpeMin, rpeMax),
      ),
      detail: detail,
    );
  }
}

/// "Based on [Back Squat ▾]" with the basis 1RM on the right, the 1RM the
/// percentages resolve against. The picker is unrestricted: any exercise in
/// the catalog can be the basis.
class _BasisRow extends ConsumerWidget {
  const _BasisRow({
    required this.exercises,
    required this.value,
    required this.currentExerciseName,
    required this.basisExerciseId,
    required this.basisExerciseName,
    required this.unit,
    required this.onChanged,
  });

  final List<Exercise> exercises;
  final Exercise? value;
  final String currentExerciseName;
  final String basisExerciseId;
  final String basisExerciseName;
  final String unit;
  final ValueChanged<Exercise?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final oneRepMax = _watchOneRepMax(ref, basisExerciseId, basisExerciseName);
    final body = Theme.of(context).textTheme.bodyMedium!;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Text('Based on', style: body.copyWith(color: palette.fg2)),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              height: 36,
              padding: const EdgeInsets.only(left: 12, right: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.borderDefault),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Exercise?>(
                  key: const Key('set_editor_basis'),
                  value: value,
                  isDense: true,
                  isExpanded: true,
                  borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
                  icon: Icon(Icons.expand_more, size: 18, color: palette.fg2),
                  style: body.copyWith(color: palette.fg1, fontWeight: FontWeight.w500),
                  items: [
                    DropdownMenuItem<Exercise?>(
                      child: Text(currentExerciseName, overflow: TextOverflow.ellipsis),
                    ),
                    for (final ex in exercises)
                      DropdownMenuItem<Exercise?>(
                        value: ex,
                        child: Text(ex.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          if (oneRepMax != null) ...[
            const SizedBox(width: 12),
            Text(
              '${oneRepMax.isEstimated ? 'Est. 1RM' : '1RM'} ${formatWeightForPreference(oneRepMax.kg, unit)}',
              style: tokens.weightSm.copyWith(color: oneRepMax.isEstimated ? palette.info : palette.fg2),
            ),
          ],
        ],
      ),
    );
  }
}

/// A field row: the label (plus [after], e.g. a One/Range toggle) on the
/// left and [trailing], usually a compact stepper, on the right. The label
/// and the stepper share one [Row], so the row reads as one field.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, this.after, this.below, this.trailing});

  final String label;
  final Widget? after;
  final Widget? below;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget left = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        if (after != null) ...[const SizedBox(width: 10), after!],
      ],
    );
    if (below != null) {
      left = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [left, const SizedBox(height: 6), below!],
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: below != null ? 10 : 0),
        child: Row(
          children: [
            left,
            const Spacer(),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The sheet's stepper: just − value +, with the theme's stepper chrome at a
/// row-sized value.
Widget _compactStepper({
  Key? key,
  required String label,
  required double value,
  required double min,
  double? max,
  required double step,
  required int decimals,
  required NomorexTokens tokens,
  required ValueChanged<double> onChanged,
}) =>
    NumberStepperField(
      key: key,
      compact: true,
      label: label,
      value: value,
      min: min,
      max: max,
      step: step,
      decimals: decimals,
      onChanged: onChanged,
      valueTextStyle: tokens.stepperValue.copyWith(fontSize: 20, height: 26 / 20),
      valueDecoration: tokens.stepperValueDecoration,
      decrementButtonStyle: tokens.stepperDecrementStyle,
      incrementButtonStyle: tokens.stepperIncrementStyle,
    );

Widget _setsCountRow({required int sets, required ValueChanged<int> onChanged}) => Builder(
      builder: (context) => _FieldRow(
        label: 'Sets',
        trailing: _compactStepper(
          label: 'Sets',
          value: sets.toDouble(),
          min: 1,
          step: 1,
          decimals: 0,
          tokens: NomorexTokens.of(context),
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
    );

/// The small ONE | RANGE toggle beside a field's label. One control, one
/// tap flips it; announced as a switch named [label] ("Rep range").
class _OneRangeToggle extends StatelessWidget {
  const _OneRangeToggle({super.key, required this.label, required this.isRange, required this.onChanged});

  final String label;
  final bool isRange;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    Widget segment(String text, bool on) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          color: on ? palette.primarySubtle : null,
          child: Text(text, style: tokens.weightXs.copyWith(color: on ? palette.primaryText : palette.fg3)),
        );
    return Semantics(
      label: label,
      toggled: isRange,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onChanged(!isRange),
        borderRadius: BorderRadius.circular(NomorexSizes.radiusSm),
        // 24px to look at, 48px to hit.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NomorexSizes.radiusSm),
              border: Border.all(color: palette.borderDefault),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [segment('ONE', !isRange), segment('RANGE', isRange)],
            ),
          ),
        ),
      ),
    );
  }
}

/// The range top to save: null unless it's actually above [low], so a range
/// the author narrowed back down to one number is stored as a single value.
T? _rangeTop<T extends num>(T low, T? high) =>
    (high != null && high > low) ? high : null;

/// A field that's one value or a range ("7 to 9" reps, "67–72.5%"). The
/// label row carries a ONE | RANGE toggle and, for one value, the stepper;
/// a range drops to a second line of two steppers joined by "to". [max] is
/// null exactly when it's a single value.
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
    required this.onChanged,
    this.labelAction,
  });

  final double value;
  final double? max;
  /// Stepper names for assistive tech: [label] alone, [minLabel] /
  /// [maxLabel] as a range.
  final String label;
  final String minLabel;
  final String maxLabel;
  final String switchLabel;
  final double floor;
  final double? ceiling;
  final double step;
  final int decimals;
  /// How far above [value] the top starts when the range is turned on.
  final double spread;
  final Key valueKey;
  final Key switchKey;
  final Key maxKey;
  final void Function(double value, double? max) onChanged;
  /// Shown after the toggle, e.g. RPE's remove button.
  final Widget? labelAction;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final top = max;
    final low = _compactStepper(
      key: valueKey,
      label: top == null ? label : minLabel,
      value: value,
      min: floor,
      max: ceiling,
      step: step,
      decimals: decimals,
      tokens: tokens,
      // Raising the bottom of a range past its top drags the top along, so
      // the pair can never be saved inverted.
      onChanged: (v) => onChanged(v, top == null ? null : (top < v ? v : top)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FieldRow(
          label: label,
          after: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OneRangeToggle(
                key: switchKey,
                label: switchLabel,
                isRange: top != null,
                // The top starts [spread] above the bottom, never past
                // [ceiling].
                onChanged: (on) {
                  final c = ceiling;
                  final start = c != null && value + spread > c ? c : value + spread;
                  onChanged(value, on ? start : null);
                },
              ),
              ?labelAction,
            ],
          ),
          trailing: top == null ? low : null,
        ),
        if (top != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                low,
                Expanded(
                  child: Text(
                    'to',
                    textAlign: TextAlign.center,
                    style: tokens.bodySmall.copyWith(color: tokens.palette.fg3),
                  ),
                ),
                _compactStepper(
                  key: maxKey,
                  label: maxLabel,
                  value: top,
                  min: value,
                  max: ceiling,
                  step: step,
                  decimals: decimals,
                  tokens: tokens,
                  onChanged: (v) => onChanged(value, v),
                ),
              ],
            ),
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
      onChanged: (v, max) => onChanged(v.round(), max?.round()),
    );

/// Optional target effort for a batch. Off, it's an "Add target RPE" link;
/// on, an RPE field (1–10 in half steps, starting at 7) with its own range
/// toggle ("RPE 6–7") and a remove button. [rpeMin] is null exactly when no
/// RPE is prescribed. The `set_editor_rpe_switch` key is on whichever
/// control turns it on or off.
class _RpeTargetInput extends StatelessWidget {
  const _RpeTargetInput({
    required this.rpeMin,
    required this.rpeMax,
    required this.onChanged,
  });

  final double? rpeMin;
  final double? rpeMax;
  final void Function(double? rpeMin, double? rpeMax) onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    final min = rpeMin;
    if (min == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Semantics(
          toggled: false,
          child: TextButton.icon(
            key: const Key('set_editor_rpe_switch'),
            style: TextButton.styleFrom(
              foregroundColor: palette.primaryText,
              padding: const EdgeInsets.symmetric(horizontal: 0),
            ),
            onPressed: () => onChanged(7, null),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add target RPE'),
          ),
        ),
      );
    }
    return _RangeInput(
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
      onChanged: onChanged,
      labelAction: IconButton(
        key: const Key('set_editor_rpe_switch'),
        tooltip: 'Remove target RPE',
        icon: Icon(Icons.close, size: 18, color: palette.fg3),
        onPressed: () => onChanged(null, null),
      ),
    );
  }
}
