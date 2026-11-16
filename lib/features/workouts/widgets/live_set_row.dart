import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/percent_range.dart';
import '../../../core/utils/rpe.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/models/one_rep_max.dart';
import '../../../shared/widgets/number_stepper_field.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/set_pr_link.dart';
import '../../../shared/widgets/summary_card.dart' show pluralize;
import '../../programs/utils/program_day_brief.dart' show repsNumber;
import '../models/workout_set.dart';
import '../utils/set_resolver.dart';

/// A set read the way a lifter loads the bar. The main line is reps by load,
/// "3 × 165 lbs / 75 kg", the thing to read first; the second line is the
/// prescription it came from, "75% of 1RM · RPE 8", small.
///
/// A load resolved from a %1RM is `info` blue (the viewer's own or estimated
/// 1RM; on another user's workout it's still the viewer's), a fixed load is
/// `fg-1`. An open-load set reads "3 × choose load". A percentage set with no
/// 1RM to resolve against reads "3 × 75%", and its second line offers the
/// [SetPrLink] shortcut. A done set dims its reps to `fg-2`, never struck
/// through; the load stays readable.
class SetPrescriptionLines extends StatelessWidget {
  const SetPrescriptionLines({
    super.key,
    required this.set,
    required this.oneRepMax,
    required this.basisExerciseId,
    required this.basisExerciseName,
    required this.unit,
    this.done = false,
    this.leading,
    this.trailing,
  });

  final WorkoutSet set;
  final OneRepMax? oneRepMax;

  /// The lift a percentage resolves against, and its name for [SetPrLink].
  final String basisExerciseId;
  final String basisExerciseName;
  final String unit;
  final bool done;

  /// Sits before the main line, centered on it (the set's checkbox); the
  /// second line indents by [leadingWidth] to stay under the main line.
  final Widget? leading;
  static const leadingWidth = 52.0;

  /// The log chip on a live session: at the end of the second line on a
  /// phone, at the end of the main line when there's room.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final repsStyle = tokens.stat.copyWith(color: done ? palette.fg2 : palette.fg1);
    final reps = repsNumber(set.targetReps, set.targetRepsMax);
    final rpe = formatRpeTarget(set.rpeMin, set.rpeMax);
    final isPct = set.weightMode == 'percentage';
    final pct = formatPercentTarget(set.percentage, set.percentageMax);
    // "75% of 1RM", or "75% of Clean & Jerk" when the set is programmed
    // against a different lift, so the load doesn't look wrong for the
    // exercise it's filed under.
    final basisLabel = set.basisExerciseId != null ? 'of $basisExerciseName' : 'of 1RM';

    final resolved = resolveSetWeightRangeKg(
      weightMode: set.weightMode,
      percentage: set.percentage,
      percentageMax: set.percentageMax,
      absoluteWeightKg: set.absoluteWeightKg,
      oneRepMaxKg: oneRepMax?.kg,
    );

    final InlineSpan load;
    final List<InlineSpan> detail;
    if (isOpenLoad(set.weightMode)) {
      load = TextSpan(text: kOpenLoadLabel, style: tokens.stat.copyWith(color: palette.fg3, fontWeight: FontWeight.w500));
      detail = [if (rpe != null) TextSpan(text: rpe)];
    } else if (isPct && resolved == null) {
      // Nothing to resolve against: the percentage stands in for the load,
      // and the second line offers the PR that would resolve it.
      load = TextSpan(text: pct, style: repsStyle);
      final linkStyle = tokens.bodySmall;
      // "No 1RM yet · set PR", or "of Clean & Jerk · set PR" when the basis is
      // another lift, so the line names what's missing.
      detail = [
        TextSpan(text: set.basisExerciseId != null ? '$basisLabel · ' : 'No 1RM yet · '),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SetPrLink(exerciseId: basisExerciseId, exerciseName: basisExerciseName, style: linkStyle),
        ),
        if (rpe != null) TextSpan(text: ' · $rpe'),
      ];
    } else if (isPct) {
      load = TextSpan(
        text: formatResolvedWeightRange(resolved!.low, resolved.high, unit, estimated: oneRepMax?.isEstimated ?? false),
        style: tokens.weightLg.copyWith(color: palette.info),
      );
      detail = [TextSpan(text: [('$pct $basisLabel'), ?rpe].join(' · '))];
    } else {
      load = TextSpan(
        text: formatWeightForPreference(resolved?.low ?? 0, unit),
        style: tokens.weightLg.copyWith(color: palette.fg1),
      );
      detail = [if (rpe != null) TextSpan(text: rpe)];
    }

    final second = detail.isEmpty
        ? null
        : Text.rich(TextSpan(children: detail), style: tokens.bodySmall, key: ValueKey('set_detail_${set.id}'));

    final main = Text.rich(
      TextSpan(children: [TextSpan(text: '$reps × ', style: repsStyle), load]),
      key: ValueKey('set_main_${set.id}'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // On a phone the main line keeps the full width and the trailing
        // chip sits at the end of the second line; with room to spare it
        // ends the main line instead, so the row stays two lines tall.
        final wide = constraints.maxWidth >= 520;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (leading != null) SizedBox(width: leadingWidth, child: Align(alignment: Alignment.centerLeft, child: leading)),
                Expanded(child: main),
                if (wide && trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
            if (second != null || (!wide && trailing != null))
              Padding(
                padding: EdgeInsets.only(top: 2, left: leading != null ? leadingWidth : 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: second ?? const SizedBox.shrink()),
                    if (!wide && trailing != null) ...[const SizedBox(width: 8), trailing!],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// What was logged on [set], as the log chip reads it: "3/3" (reps against a
/// single-number target) or "4 reps", the weight on an open-load set, and
/// "RPE 7". Null when nothing is logged.
String? loggedSummary(WorkoutSet set, String unit) {
  final parts = <String>[
    if (set.actualReps case final reps?)
      set.targetReps != null && set.targetRepsMax == null ? '$reps/${set.targetReps}' : pluralize(reps, 'rep'),
    if (isOpenLoad(set.weightMode) && set.actualWeightKg != null)
      formatWeightForPreference(set.actualWeightKg!, unit),
    if (set.actualRpe case final rpe?) 'RPE ${formatRpe(rpe)}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The compact log control on a live set: "Log" until something is logged,
/// then what was logged ("3/3 · RPE 7"). It opens [showLogSetSheet]. On a
/// session that isn't live it's plain `fg-2` text, and nothing at all when
/// nothing was logged.
class LogSetChip extends StatelessWidget {
  const LogSetChip({
    super.key,
    required this.set,
    required this.unit,
    required this.setLabel,
    required this.onLog,
  });

  final WorkoutSet set;
  final String unit;

  /// How the set is announced in the chip's name, e.g. "Warm-up set 2".
  final String setLabel;

  /// Null when the session isn't live.
  final void Function(LoggedSet result)? onLog;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final summary = loggedSummary(set, unit);
    if (onLog == null) {
      if (summary == null) return const SizedBox.shrink();
      return Text(summary, key: ValueKey('set_log_${set.id}'), style: tokens.weightSm.copyWith(color: tokens.fg2));
    }
    return Tooltip(
      message: summary == null ? 'Log $setLabel' : 'Edit the log for $setLabel',
      excludeFromSemantics: true,
      child: Semantics(
        key: ValueKey('set_log_${set.id}'),
        // Its own node, so it's announced and activated apart from the set.
        container: true,
        button: true,
        label: summary == null ? 'Log $setLabel' : '$setLabel logged: $summary. Edit',
        excludeSemantics: true,
        child: FilledButton(
          style: tokens.secondaryButtonStyle.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
            padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
            textStyle: WidgetStatePropertyAll(summary == null ? tokens.buttonSmall : tokens.weightSm),
            foregroundColor: WidgetStatePropertyAll(summary == null ? tokens.fg2 : tokens.palette.fg1),
            // 32px to look at, 48px to hit.
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          onPressed: () async {
            final result = await showLogSetSheet(context, set: set, unit: unit, setLabel: setLabel);
            if (result != null) onLog!(result);
          },
          child: Text(summary ?? 'Log'),
        ),
      ),
    );
  }
}

/// What the log sheet hands back. [cleared] means "Clear log": every logged
/// value goes back to empty and the set's done state is left alone.
class LoggedSet {
  const LoggedSet({required this.reps, required this.rpe, this.weightKg, this.cleared = false});

  const LoggedSet.cleared()
      : reps = null,
        rpe = null,
        weightKg = null,
        cleared = true;

  final int? reps;
  final double? rpe;
  final double? weightKg;
  final bool cleared;
}

/// One sheet for everything logged on a set: reps (starting at what was
/// logged, else the target), the weight on an open-load set, and an optional
/// RPE behind "Add RPE". Save hands back the values; the caller also marks the
/// set done. A bottom sheet on a phone, a centered panel wider.
Future<LoggedSet?> showLogSetSheet(
  BuildContext context, {
  required WorkoutSet set,
  required String unit,
  required String setLabel,
}) {
  final open = isOpenLoad(set.weightMode);
  final sheetUnit = unit == 'lbs' ? 'lbs' : 'kg';
  var reps = (set.actualReps ?? set.targetReps ?? 1).toDouble();
  final loggedKg = set.actualWeightKg;
  var weight = loggedKg == null ? 0.0 : (sheetUnit == 'lbs' ? kgToLbs(loggedKg) : loggedKg);
  double? rpe = set.actualRpe;
  final hasLog = set.actualReps != null || set.actualRpe != null || (open && loggedKg != null);

  Widget content(BuildContext ctx, StateSetter setState) {
    final tokens = NomorexTokens.of(ctx);
    final palette = tokens.palette;
    final inSheet = isMobile(ctx);
    NumberStepperField stepper({
      required Key key,
      required String label,
      required double value,
      required double min,
      double? max,
      required double step,
      required int decimals,
      required ValueChanged<double> onChanged,
      Widget? labelAction,
    }) =>
        NumberStepperField(
          key: key,
          labelAction: labelAction,
          label: label,
          value: value,
          min: min,
          max: max,
          step: step,
          decimals: decimals,
          onChanged: onChanged,
          valueTextStyle: tokens.stepperValue,
          valueDecoration: tokens.stepperValueDecoration,
          decrementButtonStyle: tokens.stepperDecrementStyle,
          incrementButtonStyle: tokens.stepperIncrementStyle,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, inSheet ? 0 : 12, 4, 0),
          child: Row(
            children: [
              Expanded(child: Text('Log $setLabel', style: Theme.of(ctx).textTheme.titleMedium)),
              if (hasLog)
                TextButton(
                  key: const Key('log_set_clear'),
                  onPressed: () => Navigator.pop(ctx, const LoggedSet.cleared()),
                  child: const Text('Clear log'),
                ),
              IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close, color: palette.fg2),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                stepper(
                  key: const Key('log_set_reps'),
                  label: 'Reps',
                  value: reps,
                  min: 0,
                  step: 1,
                  decimals: 0,
                  onChanged: (v) => setState(() => reps = v),
                ),
                if (open) ...[
                  const SizedBox(height: 16),
                  stepper(
                    key: const Key('log_set_weight'),
                    label: 'Weight ($sheetUnit)',
                    value: weight,
                    min: 0,
                    step: sheetUnit == 'lbs' ? 5.0 : 2.5,
                    decimals: 1,
                    onChanged: (v) => setState(() => weight = v),
                  ),
                ],
                const SizedBox(height: 16),
                if (rpe == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('log_set_add_rpe'),
                      onPressed: () => setState(() => rpe = set.rpeMin ?? 7),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add RPE'),
                    ),
                  )
                else
                  // The remove ✕ sits beside the label, not after the
                  // stepper, so the RPE stepper lines up with the Reps one.
                  stepper(
                    key: const Key('log_set_rpe'),
                    label: 'RPE',
                    value: rpe!,
                    min: kRpeMin,
                    max: kRpeMax,
                    step: kRpeStep,
                    decimals: 1,
                    onChanged: (v) => setState(() => rpe = v),
                    labelAction: IconButton(
                      key: const Key('log_set_remove_rpe'),
                      tooltip: 'Remove RPE',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close, size: 18, color: palette.fg3),
                      onPressed: () => setState(() => rpe = null),
                    ),
                  ),
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
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    key: const Key('log_set_save'),
                    onPressed: () => Navigator.pop(
                      ctx,
                      LoggedSet(
                        reps: reps.round(),
                        rpe: rpe,
                        weightKg: open ? (sheetUnit == 'lbs' ? lbsToKg(weight) : weight) : null,
                      ),
                    ),
                    child: Text(set.completed ? 'Save' : 'Save and mark done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  if (isMobile(context)) {
    return showModalBottomSheet<LoggedSet>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: StatefulBuilder(builder: content),
      ),
    );
  }
  return showDialog<LoggedSet>(
    context: context,
    builder: (ctx) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: StatefulBuilder(builder: content)),
    ),
  );
}
