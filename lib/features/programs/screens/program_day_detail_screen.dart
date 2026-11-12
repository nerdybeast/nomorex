import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/percent_range.dart';
import '../../../core/utils/rpe.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../shared/models/one_rep_max.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/set_pr_link.dart';
import '../../profile/providers/profile_provider.dart';
import '../../workouts/providers/one_rep_max_provider.dart';
import '../../workouts/utils/set_resolver.dart';
import '../models/program_day.dart';
import '../models/program_exercise.dart';
import '../models/program_set.dart';
import '../providers/program_detail_provider.dart';
import '../utils/program_day_brief.dart';

/// Read-only preview of a single program day, reached by tapping a day on a
/// program (yours or a Community one) — once a program runs, the same tap
/// opens the real logged workout instead. Reuses the cached
/// [programDetailProvider] rather than issuing a new query.
///
/// Laid out as a session brief: the day's shape first (lifts, sets, peak
/// intensity), then the main lift at full size with its loads resolved from
/// the viewer's own 1RM, then the rest in order.
class ProgramDayDetailScreen extends ConsumerWidget {
  const ProgramDayDetailScreen({super.key, required this.programId, required this.dayId});

  final String programId;
  final String dayId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(programDetailProvider(programId));
    final loads = _Loads(
      byId: ref.watch(oneRepMaxProvider).asData?.value ?? const {},
      byName: ref.watch(oneRepMaxByNameProvider).asData?.value ?? const {},
      unit: ref.watch(unitPreferenceProvider),
    );

    return Scaffold(
      appBar: AppBar(
        // The program's name for context; the day itself leads the page.
        title: Text(detail.asData?.value.name ?? '', overflow: TextOverflow.ellipsis),
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _LoadError(onRetry: () => ref.invalidate(programDetailProvider(programId))),
        data: (program) {
          final week = program.weeks.firstWhere((w) => w.days.any((d) => d.id == dayId));
          final day = week.days.firstWhere((d) => d.id == dayId);
          final theme = Theme.of(context);
          final tokens = NomorexTokens.of(context);
          final exercises = day.exercises;

          return ListView(
            // Narrower than list screens: the brief reads reps to load across a
            // row, which shouldn't stretch across a desktop window.
            padding: contentPadding(context, bottom: 32, maxWidth: 640),
            children: [
              Text(day.title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 2),
              Text(
                'Week ${week.weekNumber}${week.label != null ? ' · ${week.label}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3),
              ),
              if (day.notes != null && day.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(day.notes!, style: tokens.bodySmall),
              ],
              const SizedBox(height: 16),
              if (day.isRestDay)
                const _QuietState(title: 'Rest day', message: 'Nothing is programmed. Recover.')
              else if (exercises.isEmpty)
                const _QuietState(title: 'No workout scheduled', message: 'This day has no exercises yet.')
              else ...[
                _DayTiles(day: day, unit: loads.unit),
                const SizedBox(height: 16),
                _MainLift(exercise: exercises.first, loads: loads),
                if (exercises.length > 1) ...[
                  const SizedBox(height: 16),
                  ListGroup(
                    children: [
                      for (var i = 1; i < exercises.length; i++)
                        _LiftRow(
                          index: i + 1,
                          exercise: exercises[i],
                          loads: loads,
                          // The hero already offers this PR; don't link it twice.
                          linkedBasisId: _missingBasisId(exercises.first, loads),
                        ),
                    ],
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The viewer's 1RMs and unit, and how a set resolves against them. Sets on
/// someone else's public program carry *their* exercise ids, so lookups fall
/// back to the lift's name (see [lookupOneRepMax]).
class _Loads {
  const _Loads({required this.byId, required this.byName, required this.unit});

  final Map<String, OneRepMax> byId;
  final Map<String, OneRepMax> byName;
  final String unit;

  String basisId(ProgramSet set, ProgramExercise ex) => set.basisExerciseId ?? ex.exerciseId;

  String basisName(ProgramSet set, ProgramExercise ex) =>
      set.basisExerciseId != null ? (set.basisExerciseName ?? ex.exerciseName) : ex.exerciseName;

  OneRepMax? oneRepMax(ProgramSet set, ProgramExercise ex) => lookupOneRepMax(
        basisExerciseId: basisId(set, ex),
        basisExerciseName: basisName(set, ex),
        byExerciseId: byId,
        byExerciseName: byName,
      );

  ({double low, double? high})? resolve(ProgramSet set, ProgramExercise ex) => resolveSetWeightRangeKg(
        weightMode: set.weightMode,
        percentage: set.percentage,
        percentageMax: set.percentageMax,
        absoluteWeightKg: set.absoluteWeightKg,
        oneRepMaxKg: oneRepMax(set, ex)?.kg,
      );
}

/// What a lift asks for overall: its load range across every set it can
/// resolve, whether any of that rests on an estimated 1RM, and whether some
/// percentage set has no 1RM to resolve against.
class _LiftLoad {
  _LiftLoad(ProgramExercise ex, _Loads loads) {
    for (final set in ex.sets) {
      if (isOpenLoad(set.weightMode)) {
        hasOpen = true;
        continue;
      }
      final r = loads.resolve(set, ex);
      if (r == null) {
        if (set.weightMode == 'percentage') missingBasis ??= set;
        continue;
      }
      final top = r.high ?? r.low;
      low = low == null || r.low < low! ? r.low : low;
      high = high == null || top > high! ? top : high;
      if (set.weightMode == 'percentage' && (loads.oneRepMax(set, ex)?.isEstimated ?? false)) estimated = true;
    }
  }

  double? low;
  double? high;
  bool estimated = false;
  bool hasOpen = false;

  /// The first percentage set with no 1RM behind it: what Set PR points at.
  ProgramSet? missingBasis;

  bool get resolved => low != null;
}

class _DayTiles extends StatelessWidget {
  const _DayTiles({required this.day, required this.unit});

  final ProgramDay day;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final peakPct = peakPercentage(day);
    final peakKg = peakAbsoluteKg(day);
    return Row(
      children: [
        Expanded(child: _Tile(value: '${day.exercises.length}', label: day.exercises.length == 1 ? 'lift' : 'lifts')),
        const SizedBox(width: 8),
        Expanded(child: _Tile(value: '${totalSets(day)}', label: totalSets(day) == 1 ? 'set' : 'sets')),
        if (peakPct != null || peakKg != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: peakPct != null
                ? _Tile(value: formatPercentTarget(peakPct, null), label: 'peak intensity', hot: true)
                : _Tile(value: formatWeightForPreference(peakKg!, unit), label: 'top load', hot: true),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label, this.hot = false});

  final String value;
  final String label;

  /// The day's peak: the one number set in orange.
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.bg1,
        border: Border.all(color: palette.borderSubtle),
        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: tokens.stat.copyWith(color: hot ? palette.primaryText : palette.fg1)),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tokens.fg3)),
        ],
      ),
    );
  }
}

/// The day's first lift at full size: orange index and edge, its load range
/// large in blue mono, and its set groups as rows.
class _MainLift extends StatelessWidget {
  const _MainLift({required this.exercise, required this.loads});

  final ProgramExercise exercise;
  final _Loads loads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final load = _LiftLoad(exercise, loads);
    final groups = groupConsecutiveSets(exercise.sets);
    final percentages = exercise.sets.where((s) => s.weightMode == 'percentage').toList();
    final basisSet = percentages.isEmpty ? null : percentages.first;
    final basisMax = basisSet == null ? null : loads.oneRepMax(basisSet, exercise);

    final pctRange = basisSet == null ? null : formatPercentTarget(_minPct(percentages), _maxPctOrNull(percentages));

    return Container(
      key: const Key('program_day_main_lift'),
      decoration: BoxDecoration(
        color: palette.bg1,
        border: Border.all(color: palette.primaryBorder),
        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
      ),
      // The border insets the child by its 1px width, so the band is clipped
      // to the border's inner curve; clipping to the outer radius let its
      // corners poke past the border.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg - 1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The warmth sits in a header band behind the name, as a row tint
            // (like today's day row), not as a fill for the whole card.
            Container(
              color: Color.alphaBlend(palette.primarySubtle, palette.bg1),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('1', style: _indexStyle(context, palette.primaryText)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(exercise.exerciseName, style: theme.textTheme.titleLarge)),
                    ],
                  ),
                  if (exercise.notes != null && exercise.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(exercise.notes!, style: tokens.bodySmall),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _HeadlineLoad(exercise: exercise, load: load, loads: loads, pctRange: pctRange),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        [
                          _setsSummary(groups),
                          // With no 1RM the percentage is the headline, so it
                          // isn't repeated here.
                          if (pctRange != null && load.resolved)
                            '$pctRange'
                                '${basisMax == null ? '' : ' of ${formatWeightForPreference(basisMax.kg, loads.unit)} ${basisMax.isEstimated ? 'est. 1RM' : 'PR'}'}',
                        ].join('\n'),
                        textAlign: TextAlign.right,
                        style: tokens.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final g in groups) _GroupRow(group: g, exercise: exercise, loads: loads),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The main lift's load, as big as the page sets anything: the resolved
/// range in blue mono, or what stands in for it when nothing resolves.
class _HeadlineLoad extends StatelessWidget {
  const _HeadlineLoad({required this.exercise, required this.load, required this.loads, required this.pctRange});

  final ProgramExercise exercise;
  final _LiftLoad load;
  final _Loads loads;

  /// The lift's %1RM range ("70–75%"), the headline when no 1RM resolves it.
  final String? pctRange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final big = tokens.weightLg.copyWith(fontSize: 28, height: 32 / 28, letterSpacing: -0.4);
    final unitStyle = theme.textTheme.bodyMedium?.copyWith(color: tokens.fg2);
    final low = load.low;
    if (low != null) {
      final text = formatWeightRangeForPreference(low, load.high == low ? null : load.high, loads.unit);
      // The number carries the weight; the unit steps down beside it. "Both"
      // reads "220 lbs / 100 kg", which has no single unit to split off.
      final suffix = ' ${loads.unit}';
      final split = loads.unit != 'both' && text.endsWith(suffix);
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: split ? text.substring(0, text.length - suffix.length) : text,
              style: big.copyWith(color: palette.info),
            ),
            if (split) TextSpan(text: suffix, style: unitStyle),
            if (load.estimated) TextSpan(text: ' (est.)', style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3)),
          ],
        ),
        key: const Key('program_day_main_load'),
      );
    }
    final missing = load.missingBasis;
    if (missing != null) {
      // No 1RM: the prescription itself stays the focal figure, with the
      // way to resolve it right under it.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pctRange != null)
            Text(
              pctRange!,
              key: const Key('program_day_main_pct'),
              style: tokens.stat.copyWith(fontSize: 28, height: 32 / 28, letterSpacing: -0.4),
            ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('No 1RM yet · ', style: tokens.bodySmall),
              _setPrLink(missing, exercise, loads, tokens.bodySmall),
            ],
          ),
        ],
      );
    }
    return Text(kOpenLoadLabel, style: theme.textTheme.titleLarge?.copyWith(color: tokens.fg3));
  }
}

/// One group of identical sets: "3 × 3", what it's measured against, and
/// the load, right-aligned so loads line up down the lift.
class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.exercise, required this.loads});

  final SetGroup group;
  final ProgramExercise exercise;
  final _Loads loads;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final set = group.first;
    final isPct = set.weightMode == 'percentage';
    final middle = [
      if (isPct)
        '${formatPercentTarget(set.percentage, set.percentageMax)}'
            '${set.basisExerciseId != null ? ' ${loads.basisName(set, exercise)}' : ''}',
      ?formatRpeTarget(set.rpeMin, set.rpeMax),
    ].join(' · ');

    Widget value;
    if (isOpenLoad(set.weightMode)) {
      value = Text(kOpenLoadLabel, style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3));
    } else {
      final r = loads.resolve(set, exercise);
      if (r == null) {
        // No 1RM to resolve against: the lift's headline (or its row) carries
        // the one Set PR link, so the set rows don't repeat it.
        value = const SizedBox.shrink();
      } else {
        final estimated = isPct && (loads.oneRepMax(set, exercise)?.isEstimated ?? false);
        value = Text(
          formatResolvedWeightRange(r.low, r.high, loads.unit, estimated: estimated),
          textAlign: TextAlign.right,
          style: tokens.weight.copyWith(color: isPct ? palette.info : palette.fg1),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: palette.borderSubtle)),
      ),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(setGroupLabel(group), style: theme.textTheme.bodyMedium)),
          Expanded(
            child: Text(middle, style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3)),
          ),
          const SizedBox(width: 8),
          value,
        ],
      ),
    );
  }
}

/// Every lift after the first: its order, name, a one-line summary ("4 × 3
/// · 50–70% of Snatch") and its load range on the right, as a coach's sheet
/// collapses it.
class _LiftRow extends StatelessWidget {
  const _LiftRow({required this.index, required this.exercise, required this.loads, this.linkedBasisId});

  final int index;
  final ProgramExercise exercise;
  final _Loads loads;

  /// A basis lift whose Set PR link the page already shows; this row doesn't
  /// repeat it.
  final String? linkedBasisId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final groups = groupConsecutiveSets(exercise.sets);
    final load = _LiftLoad(exercise, loads);
    final pct = exercise.sets.where((s) => s.weightMode == 'percentage').toList();
    final allPct = pct.isNotEmpty && pct.length == exercise.sets.length;
    final basisIds = pct.map((s) => s.basisExerciseId).toSet();
    final first = exercise.sets.isEmpty ? null : exercise.sets.first;
    final rpe = first == null ? null : formatRpeTarget(first.rpeMin, first.rpeMax);
    final summary = [
      _setsSummary(groups),
      if (allPct && basisIds.length == 1)
        '${formatPercentTarget(_minPct(pct), _maxPctOrNull(pct))}'
            '${first!.basisExerciseId != null ? ' of ${loads.basisName(first, exercise)}' : ''}',
      if (groups.length == 1 && rpe != null) rpe,
    ].join(' · ');

    Widget value;
    final low = load.low;
    final missing = load.missingBasis;
    if (low != null) {
      value = Text(
        formatResolvedWeightRange(low, load.high == low ? null : load.high, loads.unit, estimated: load.estimated),
        textAlign: TextAlign.right,
        style: tokens.weight.copyWith(color: pct.isNotEmpty ? palette.info : palette.fg1),
      );
    } else if (missing != null && loads.basisId(missing, exercise) != linkedBasisId) {
      value = _setPrLink(missing, exercise, loads, tokens.bodySmall);
    } else if (missing != null) {
      // The hero already links this PR; say why there's no load instead of
      // leaving the column blank or linking it twice.
      value = Text(
        'needs ${loads.basisName(missing, exercise)} PR',
        style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3),
      );
    } else {
      value = Text(kOpenLoadLabel, style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3));
    }

    return GroupableTile(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Text('$index', style: _indexStyle(context, tokens.fg3))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exercise.exerciseName, style: theme.textTheme.titleSmall),
                Text(summary, style: tokens.bodySmall),
                if (exercise.notes != null && exercise.notes!.isNotEmpty)
                  Text(
                    exercise.notes!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          value,
        ],
      ),
    );
  }
}

/// A lift's order number: Inter with tabular figures (mono is for loads).
TextStyle? _indexStyle(BuildContext context, Color color) => Theme.of(context)
    .textTheme
    .labelMedium
    ?.copyWith(color: color, height: 20 / 12, fontFeatures: const [FontFeature.tabularFigures()]);

/// The id of the main lift's basis when the page offers its Set PR link.
String? _missingBasisId(ProgramExercise main, _Loads loads) {
  final load = _LiftLoad(main, loads);
  final missing = load.missingBasis;
  return load.resolved || missing == null ? null : loads.basisId(missing, main);
}

/// Set PR for a set's basis lift, naming that lift when it isn't the one on
/// the row ("set Snatch PR" beside Snatch Pull), so it's clear whose PR it is.
Widget _setPrLink(ProgramSet set, ProgramExercise exercise, _Loads loads, TextStyle? style) {
  final name = loads.basisName(set, exercise);
  final other = set.basisExerciseId != null && name.toLowerCase() != exercise.exerciseName.toLowerCase();
  return SetPrLink(
    exerciseId: loads.basisId(set, exercise),
    exerciseName: name,
    style: style,
    label: other ? 'set $name PR' : 'set PR',
  );
}

/// "6 × 3" when every set shares its reps, "4 sets" when they don't.
String _setsSummary(List<SetGroup> groups) {
  final all = [for (final g in groups) ...g.sets];
  if (all.isEmpty) return 'No sets';
  final reps = all.first;
  final uniform = all.every((s) => s.targetReps == reps.targetReps && s.targetRepsMax == reps.targetRepsMax);
  return uniform
      ? '${all.length} × ${repsNumber(reps.targetReps, reps.targetRepsMax)}'
      : '${all.length} sets';
}

double? _minPct(List<ProgramSet> sets) {
  double? m;
  for (final s in sets) {
    final p = s.percentage;
    if (p != null && (m == null || p < m)) m = p;
  }
  return m;
}

double? _maxPctOrNull(List<ProgramSet> sets) {
  double? m;
  for (final s in sets) {
    final p = s.percentageMax ?? s.percentage;
    if (p != null && (m == null || p > m)) m = p;
  }
  return m == _minPct(sets) ? null : m;
}

class _QuietState extends StatelessWidget {
  const _QuietState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.bg1,
        border: Border.all(color: palette.borderSubtle),
        borderRadius: BorderRadius.circular(NomorexSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(message, style: NomorexTokens.of(context).bodySmall),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Couldn't load this day", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Check your connection and try again.', textAlign: TextAlign.center, style: tokens.bodySmall),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('program_day_retry'),
              style: tokens.secondaryButtonStyle.copyWith(
                minimumSize: const WidgetStatePropertyAll(Size(160, NomorexSizes.controlHeightLg)),
              ),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
