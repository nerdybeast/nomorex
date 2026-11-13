import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/archived_pill.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/copied_from_badge.dart';
import '../../../shared/widgets/summary_card.dart';
import '../models/program.dart';
import '../models/program_day.dart';
import '../models/program_instance.dart';
import '../models/program_week.dart';
import '../providers/program_detail_provider.dart';
import '../providers/program_instance_workouts_provider.dart';
import '../providers/program_instances_list_provider.dart';
import '../providers/program_instances_provider.dart';
import '../providers/programs_provider.dart';
import '../utils/program_day_summary.dart';
import '../utils/program_progress.dart';
import '../utils/program_stats.dart';
import '../widgets/program_day_card.dart';
import '../widgets/program_run_status.dart';
import '../widgets/program_stats_chips.dart';
import '../widgets/start_program_dialog.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../shell/widgets/breadcrumb_title.dart';

/// Read-only rollup of an authored program (mirrors WorkoutDetailScreen's
/// read affordances), plus the "Start Program" call to action that
/// materializes it into logged workouts via the start_program RPC.
class ProgramDetailScreen extends ConsumerWidget {
  const ProgramDetailScreen({super.key, required this.programId});
  final String programId;

  Future<void> _startProgram(BuildContext context, WidgetRef ref, int dayCount, int workoutCount) async {
    final startDate =
        await showStartProgramDialog(context, dayCount: dayCount, workoutCount: workoutCount);
    if (startDate == null || !context.mounted) return;

    try {
      final instanceId =
          await ref.read(programInstancesProvider.notifier).startProgram(programId, startDate);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Program started')),
      );
      context.pushReplacement(AppConstants.routeProgramInstanceDetail(instanceId));
    } catch (e, st) {
      // The raw error goes to Sentry, not the screen: it means nothing to a
      // lifter, and it can carry database details.
      await Sentry.captureException(e, stackTrace: st);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("Couldn't start the program. Check your connection and try again."),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _startProgram(context, ref, dayCount, workoutCount),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(programDetailProvider(programId));
    final activeInstances = ref.watch(currentProgramInstancesProvider).asData?.value ?? const [];
    ProgramInstance? activeInstance;
    for (final instance in activeInstances) {
      if (instance.programId == programId) {
        activeInstance = instance;
        break;
      }
    }

    // An archived program opens read-only: restoring is the only action.
    final isArchived = detail.asData?.value.isArchived ?? false;

    return Scaffold(
      appBar: AppBar(
        title: BreadcrumbTitle(title: 'Program', current: detail.asData?.value.name),
        actions: [
          if (!isArchived)
            IconButton(
              tooltip: 'Edit program',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(AppConstants.routeProgramEdit(programId)),
            ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _LoadError(onRetry: () => ref.invalidate(programDetailProvider(programId))),
        data: (program) => ListView(
          padding: contentPadding(context),
          children: [
            Text(program.name, style: Theme.of(context).textTheme.headlineMedium),
            if (program.isArchived) ...[
              const SizedBox(height: 8),
              const Align(alignment: Alignment.centerLeft, child: ArchivedPill()),
            ],
            if (program.isCopy) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: CopiedFromBadge(
              isCopy: true,
              isImported: program.isImported,
              copiedFromUserId: program.copiedFromUserId,
              copiedFromDisplayName: program.copiedFromDisplayName,
              copiedFromSourceId: program.copiedFromProgramId,
            ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Created ${formatDate(program.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: NomorexTokens.of(context).fg3),
            ),
            if (program.description != null && program.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Description(program.description!),
              // The description ends in its own Show more or an 8px gap.
              const SizedBox(height: 4),
            ] else
              const SizedBox(height: 12),
            _ProgramFacts(program: program),
            const SizedBox(height: 24),
            if (program.isArchived) ...[
              FilledButton(
                key: const Key('program_detail_restore'),
                style: NomorexTokens.of(context).secondaryButtonStyle,
                onPressed: () =>
                    ref.read(programsProvider.notifier).restoreProgram(program.id),
                child: const Text('Restore'),
              ),
              const SizedBox(height: 16),
            ],
            if (program.weeks.isEmpty)
              const Center(child: Text('This program has no weeks yet.'))
            else ...[
              if (program.isArchived)
                const SizedBox.shrink()
              else if (activeInstance != null) ...[
                ProgramRunStatus(
                  upcoming: isProgramUpcoming(activeInstance.startedAt),
                  date: formatDate(activeInstance.startedAt),
                ),
                const SizedBox(height: 12),
                if (!isProgramUpcoming(activeInstance.startedAt))
                  _TodayRow(program: program, run: activeInstance),
                FilledButton.icon(
                  onPressed: () => context
                      .push(AppConstants.routeProgramInstanceDetail(activeInstance!.id)),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('View progress'),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: () => _startProgram(
                    context,
                    ref,
                    program.weeks.fold<int>(0, (sum, w) => sum + w.days.length),
                    _workoutCount(program),
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start program'),
                ),
                const SizedBox(height: 8),
                // Starting commits a lot: say so before the dialog does.
                Text(
                  'Schedules ${pluralize(_workoutCount(program), 'workout')} from the date you pick.',
                  key: const Key('program_start_hint'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: NomorexTokens.of(context).fg3),
                ),
              ],
              // Expand all's own button height supplies the rest of the gap.
              const SizedBox(height: 8),
              _WeekList(program: program, run: activeInstance),
            ],
          ],
        ),
      ),
    );
  }
}

/// Training days: each non-rest day becomes one workout when started.
int _workoutCount(Program program) =>
    templateStats(program.weeks.map(StatsWeek.fromWeek).toList()).workouts;

/// Today's day of a running program, above everything else it's about to
/// do: the day (with its TODAY pill) and its lifts, tapping straight into the scheduled
/// workout. Nothing shows outside the run's dates or for a rest day with
/// nothing to open (the row still says it's a rest day).
class _TodayRow extends ConsumerWidget {
  const _TodayRow({required this.program, required this.run});

  final Program program;
  final ProgramInstance run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ProgramDay? today;
    for (final week in program.weeks) {
      for (final day in week.days) {
        if (isProgramDayToday(run.startedAt, day.position)) today = day;
      }
    }
    final day = today;
    if (day == null) return const SizedBox.shrink();
    final workouts = ref.watch(programInstanceWorkoutsProvider(run.id)).asData?.value ?? const {};
    final workoutId = workouts[day.id];
    final canOpen = programDayHasContent(day);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ListGroup(
        children: [
          ProgramDayCard(
            key: const Key('program_today_row'),
            // The TODAY pill already says when; the title stays the day's own.
            title: day.title,
            subtitle: programDaySubtitle(day),
            highlighted: true,
            showChevron: canOpen,
            // The run's own workout when there is one; the run screen
            // otherwise (a day added to the template after the start).
            onTap: !canOpen
                ? null
                : () => context.push(workoutId != null
                    ? AppConstants.routeWorkoutDetail(workoutId)
                    : AppConstants.routeProgramInstanceDetail(run.id)),
          ),
        ],
      ),
    );
  }
}

/// Weeks, days and workouts with their icons — the same facts the Programs
/// list shows under each program. The created date sits under the title.
class _ProgramFacts extends StatelessWidget {
  const _ProgramFacts({required this.program});

  final Program program;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: programStatsChips(templateStats(program.weeks.map(StatsWeek.fromWeek).toList())),
    );
  }
}

/// The program's weeks as collapsible sections. Only the week that matters
/// opens: this week for a running program, week 1 otherwise. Six expanded
/// weeks were a five-screen scroll that pushed Start out of reach. Expand all
/// is there for reading the whole block at once.
class _WeekList extends StatefulWidget {
  const _WeekList({required this.program, required this.run});

  final Program program;
  final ProgramInstance? run;

  @override
  State<_WeekList> createState() => _WeekListState();
}

class _WeekListState extends State<_WeekList> {
  late Set<int> _open = {_initialWeek()};

  int _initialWeek() => currentWeekIndex(
        [for (final w in widget.program.weeks) [for (final d in w.days) d.position]],
        widget.run?.startedAt,
      );

  @override
  void didUpdateWidget(_WeekList old) {
    super.didUpdateWidget(old);
    // A run starting or ending moves the week that matters.
    if (old.run?.id != widget.run?.id) _open = {_initialWeek()};
  }

  @override
  Widget build(BuildContext context) {
    final weeks = widget.program.weeks;
    final allOpen = _open.length == weeks.length;
    final run = widget.run;
    final live = run != null && !isProgramUpcoming(run.startedAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (weeks.length > 1)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('program_weeks_toggle_all'),
              onPressed: () => setState(() {
                _open = allOpen ? {} : {for (var i = 0; i < weeks.length; i++) i};
              }),
              child: Text(allOpen ? 'Collapse all' : 'Expand all'),
            ),
          ),
        for (var i = 0; i < weeks.length; i++)
          _WeekSection(
            week: weeks[i],
            programId: widget.program.id,
            expanded: _open.contains(i),
            todayStartedAt: live ? run.startedAt : null,
            onToggle: () => setState(() {
              _open = {..._open};
              if (!_open.remove(i)) _open.add(i);
            }),
          ),
      ],
    );
  }
}

class _WeekSection extends StatelessWidget {
  const _WeekSection({
    required this.week,
    required this.programId,
    required this.expanded,
    required this.onToggle,
    this.todayStartedAt,
  });

  final ProgramWeek week;
  final String programId;
  final bool expanded;
  final VoidCallback onToggle;

  /// A live run's start date, so today's day can be marked; null otherwise.
  final DateTime? todayStartedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final days = week.days.length;
    final workouts = week.days.where((d) => !d.isRestDay).length;
    final heading = 'Week ${week.weekNumber}${week.label != null ? ' · ${week.label}' : ''}';
    final startedAt = todayStartedAt;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              key: Key('program_week_toggle_${week.id}'),
              borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // title-3, so the open week's days carry the weight
                          // rather than six equally loud headings.
                          Semantics(
                            header: true,
                            child: Text(heading, style: theme.textTheme.titleMedium),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${pluralize(days, 'day')} · ${pluralize(workouts, 'workout')}',
                            style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3),
                          ),
                          if (week.notes != null && week.notes!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(week.notes!, style: tokens.bodySmall),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOut,
                      child: Icon(Icons.expand_more, color: tokens.fg3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 4),
            ListGroup(
              children: [
                for (final day in week.days)
                  ProgramDayCard(
                    title: day.title,
                    subtitle: programDaySubtitle(day),
                    highlighted: startedAt != null && isProgramDayToday(startedAt, day.position),
                    showChevron: programDayHasContent(day),
                    onTap: programDayHasContent(day)
                        ? () => context.push(AppConstants.routeProgramDayDetail(programId, day.id))
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

/// The program's description in secondary text, clamped to four lines with
/// a Show more toggle once it runs longer, so it can't push the facts and
/// the Start button down the page.
class _Description extends StatefulWidget {
  const _Description(this.text);

  final String text;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  static const _clampLines = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.fg2);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: _clampLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : _clampLines,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (!overflows && !_expanded) const SizedBox(height: 8),
            if (overflows || _expanded)
              TextButton(
                key: const Key('program_description_toggle'),
                style: TextButton.styleFrom(
                  foregroundColor: tokens.primaryText,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, NomorexSizes.controlHeight),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Show less' : 'Show more'),
              ),
          ],
        );
      },
    );
  }
}

/// A program that failed to load: what happened in plain words, and a way to
/// try again. The raw error isn't shown: it means nothing to a lifter.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Couldn't load this program", style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: NomorexTokens.of(context).bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('program_detail_retry'),
              style: NomorexTokens.of(context).secondaryButtonStyle.copyWith(
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
