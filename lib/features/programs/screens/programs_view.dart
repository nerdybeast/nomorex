import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/archived_toggle.dart';
import '../../../shared/widgets/archived_row_actions.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/copied_from_badge.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/dashboard_empty_state_card.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/summary_card.dart';
import '../utils/program_stats.dart';
import '../widgets/program_run_status.dart';
import '../widgets/program_stats_chips.dart';
import '../widgets/program_weeks_tile.dart';
import '../providers/program_instances_provider.dart';
import '../models/program.dart';
import '../models/program_instance.dart';
import '../providers/program_instances_list_provider.dart';
import '../providers/programs_provider.dart';
import '../utils/program_progress.dart';
import '../../../shared/widgets/load_failure.dart';
import '../../../shared/widgets/action_sheet.dart';
import '../utils/start_program_flow.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../shared/widgets/start_option_tile.dart';
import '../../../core/theme/app_theme.dart';
import '../../ai/providers/ai_import_intake_provider.dart';
import '../../shell/nav_section.dart';
import '../providers/finished_program_instances_provider.dart';

/// The run whose row foot gets the page's one orange fill: the first with
/// a workout today not yet finished (Today's workout), else the first whose
/// schedule is over (Complete program). Null when neither applies, a rest
/// day or a day already trained, when the page has no orange at all.
String? primaryRunId(List<ProgramInstance> runs) {
  for (final run in runs) {
    if (run.todaysWorkoutId != null && !run.todaysWorkoutsDone) return run.id;
  }
  for (final run in runs) {
    if (run.scheduleFinished) return run.id;
  }
  return null;
}

/// Training's Programs view: search, the Archived toggle and the list. It has
/// no app bar of its own; `TrainingScreen` supplies one, calling [refresh] and
/// [isRefreshing] for its Refresh action.
class ProgramsView extends ConsumerStatefulWidget {
  const ProgramsView({super.key});

  static bool isRefreshing(WidgetRef ref) =>
      ref.watch(programsProvider).isRefreshing || ref.watch(archivedProgramsProvider).isRefreshing;

  static void refresh(WidgetRef ref) {
    ref.read(programsProvider.notifier).refresh();
    ref.read(archivedProgramsProvider.notifier).refresh();
  }

  @override
  ConsumerState<ProgramsView> createState() => _ProgramsViewState();
}

class _ProgramsViewState extends ConsumerState<ProgramsView> {
  final _search = TextEditingController();
  String _searchQuery = '';
  bool _showArchived = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _search.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(programsProvider);
    final archivedAsync = ref.watch(archivedProgramsProvider);
    final archivedCount = archivedAsync.asData?.value.length;
    final mobile = isMobile(context);
    final runs = ref.watch(currentProgramInstancesProvider).asData?.value ?? const <ProgramInstance>[];
    final activeIds = {for (final p in activeAsync.asData?.value ?? const <Program>[]) p.id};
    // While a program is current, this page is about that run, so building
    // another isn't its main action, even on a rest day.
    final hasCurrent = runs.any((r) => activeIds.contains(r.programId));

    return Column(
      children: [
        Padding(
          padding: contentPadding(context, top: 12, bottom: 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('programs_search'),
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: _showArchived ? 'Search archived programs…' : 'Search programs…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            key: const Key('programs_search_clear'),
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear search',
                            onPressed: _clearSearch,
                          ),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              // Nothing to switch to while nothing is archived (or the count
              // is still loading, so it doesn't flash in and out); it comes
              // back with the first archived program and stays while it's on.
              if ((archivedCount ?? 0) > 0 || _showArchived) ...[
                const SizedBox(width: 8),
                ArchivedToggle(
                  key: const Key('archived_toggle'),
                  selected: _showArchived,
                  count: archivedCount,
                  onChanged: (v) => setState(() => _showArchived = v),
                ),
              ],
              // The page's one orange fill until a program is current: then
              // the current row's foot (Today's workout, Complete program)
              // is what this page is for, and this steps down to the neutral
              // button. On a phone, New in the bottom bar already offers it
              // and the row has no room.
              if (!mobile && !_showArchived) ...[
                const SizedBox(width: 8),
                // Keyed by its role so a change of style (when the runs
                // load) swaps the button rather than animating between two
                // text styles, which Flutter can't interpolate.
                KeyedSubtree(
                  key: ValueKey(hasCurrent),
                  child: FilledButton.icon(
                    key: const Key('programs_new'),
                    style: (hasCurrent ? NomorexTokens.of(context).secondaryButtonStyle : const ButtonStyle())
                        .copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, NomorexSizes.touchTarget))),
                    onPressed: () => context.push(AppConstants.routeProgramNew),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New program'),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _showArchived
              ? _ProgramList(key: const ValueKey('archived'), programsAsync: archivedAsync, archived: true, query: _searchQuery, onClearSearch: _clearSearch, onRetry: () => ref.invalidate(archivedProgramsProvider))
              : _ProgramList(key: const ValueKey('active'), programsAsync: activeAsync, archived: false, query: _searchQuery, onClearSearch: _clearSearch, onRetry: () => ref.invalidate(programsProvider)),
        ),
      ],
    );
  }
}

/// The list, in two groups: programs with a run going (or about to start)
/// first, under Current, where the lifter looks for today's session; the
/// rest under Library. The Library header only shows beside Current, since
/// alone it labels nothing.
class _ProgramList extends ConsumerWidget {
  const _ProgramList({
    super.key,
    required this.programsAsync,
    required this.archived,
    required this.query,
    required this.onRetry,
    required this.onClearSearch,
  });

  /// Reloads whichever list this is, after a failed load.
  final VoidCallback onRetry;

  /// Empties the search field, from the no-results state.
  final VoidCallback onClearSearch;

  final AsyncValue<List<Program>> programsAsync;
  final bool archived;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Runs and run history only label rows, so while they load (or if they
    // fail) the programs show without them rather than waiting.
    final runs = archived
        ? const <ProgramInstance>[]
        : ref.watch(currentProgramInstancesProvider).asData?.value ?? const <ProgramInstance>[];
    final finished = archived
        ? const <ProgramInstance>[]
        : ref.watch(finishedProgramInstancesProvider).asData?.value ?? const <ProgramInstance>[];

    return programsAsync.whenLoaded(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => LoadFailureView(
        title: archived ? "Couldn't load your archived programs" : "Couldn't load your programs",
        retrying: programsAsync.retrying,
        onRetry: onRetry,
      ),
      data: (programs) {
        if (programs.isEmpty) {
          return ListView(
            padding: shellListPadding(context),
            children: [
              DashboardEmptyStateCard(
                ctaStyle: EmptyStateCtaStyle.link,
                icon: archived ? Icons.archive_outlined : Icons.checklist_outlined,
                title: archived ? 'No archived programs' : 'No programs yet',
                message: archived
                    ? 'Programs you archive show up here.'
                    : 'Build a reusable template to plan your training.',
                // Wider, New program sits beside search already; one way
                // to create is enough.
                ctaLabel: archived || !isMobile(context) ? null : 'Create your first program',
                onCta: archived || !isMobile(context) ? null : () => context.push(AppConstants.routeProgramNew),
              ),
              if (!archived) ...[const SizedBox(height: 24), const _AddProgramGroup()],
            ],
          );
        }
        final q = query.toLowerCase();
        final filtered = q.isEmpty
            ? programs
            : programs.where((p) {
                final name = p.name.toLowerCase();
                final description = (p.description ?? '').toLowerCase();
                return name.contains(q) || description.contains(q);
              }).toList();
        if (filtered.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    archived ? 'No archived programs match "$query".' : 'No programs match "$query".',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('programs_no_results_clear'),
                    onPressed: onClearSearch,
                    child: const Text('Clear search'),
                  ),
                ],
              ),
            ),
          );
        }

        // Current runs in the order they started.
        final byId = {for (final p in filtered) p.id: p};
        final running = [
          for (final run in runs)
            if (byId[run.programId] case final program?) (program: program, run: run),
        ];
        final runningIds = {for (final r in running) r.program.id};
        final primaryId = primaryRunId([for (final r in running) r.run]);
        // The most recent finished run of each program: [finished] is newest
        // first, so the first one seen wins.
        final lastRun = <String, DateTime>{};
        for (final run in finished) {
          lastRun.putIfAbsent(run.programId, () => run.completedAt ?? run.startedAt);
        }
        // The library leads with what was run most recently, the way a
        // lifter remembers programs, then newest created.
        DateTime recency(Program p) => lastRun[p.id] ?? p.createdAt;
        final library = [for (final p in filtered) if (!runningIds.contains(p.id)) p]
          ..sort((a, b) => recency(b).compareTo(recency(a)));

        return ListView(
          padding: shellListPadding(context),
          children: [
            if (running.isNotEmpty)
              ListGroup(
                key: const Key('programs_running'),
                // "Current" rather than "Running": it also holds runs that
                // start soon, and matches Home's Current programs.
                header: const ListGroupHeader(title: 'Current'),
                children: [
                  for (final r in running)
                    _ProgramTile(
                      program: r.program,
                      run: r.run,
                      showArchived: false,
                      primary: r.run.id == primaryId,
                    ),
                ],
              ),
            if (running.isNotEmpty && library.isNotEmpty) const SizedBox(height: 24),
            if (library.isNotEmpty)
              ListGroup(
                key: const Key('programs_library'),
                header: running.isEmpty ? null : const ListGroupHeader(title: 'Library'),
                children: [
                  for (final p in library)
                    _ProgramTile(program: p, lastRun: lastRun[p.id], showArchived: archived),
                ],
              ),
            if (!archived && q.isEmpty) ...[const SizedBox(height: 24), const _AddProgramGroup()],
          ],
        );
      },
    );
  }
}

/// Other ways to a program, under the list: importing one from paper (while
/// imports are switched on) and finding one in Community. Building one is
/// New program beside search, or New in the bottom bar on a phone.
class _AddProgramGroup extends ConsumerWidget {
  const _AddProgramGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final importEnabled = ref.watch(aiImportLimitsProvider).asData?.value.enabled ?? false;
    return ListGroup(
      key: const Key('programs_add'),
      header: const ListGroupHeader(title: 'Add a program'),
      children: [
        if (importEnabled)
          StartOptionTile(
            key: const Key('programs_add_import'),
            icon: kAiImportAction.icon,
            title: 'Import a program',
            detail: "From a PDF or photos of your coach's sheet.",
            onTap: () => context.push(kAiImportAction.route),
          ),
        StartOptionTile(
          key: const Key('programs_add_community'),
          icon: NavSection.community.icon,
          title: 'Find a program in Community',
          detail: 'Save your own copy of a program someone shared.',
          onTap: () => context.go(AppConstants.routeCommunity),
        ),
      ],
    );
  }
}

class _ProgramTile extends ConsumerWidget {
  const _ProgramTile({
    required this.program,
    required this.showArchived,
    this.run,
    this.lastRun,
    this.primary = false,
  });

  final Program program;
  final bool showArchived;

  /// The program's active run, for a row under Current.
  final ProgramInstance? run;

  /// This row's foot button is the page's main action (see
  /// [primaryRunId]), so it takes the orange fill.
  final bool primary;

  /// When the program's most recent finished run ended, for a Library row.
  final DateTime? lastRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final description = program.description?.trim();

    final activeInstance = run;

    // A running program reads "2 of 8 weeks"; otherwise plain totals from the
    // template. The run's own structure wins so "of Y" matches what it started
    // with even if the template was edited since.
    final templateWeeks = [
      for (final w in program.weeks)
        StatsWeek([
          for (final d in w.days)
            StatsDay.fromDay(d),
        ]),
    ];
    final stats = activeInstance?.stats ?? templateStats(templateWeeks);
    final daysPerWeek = daysPerWeekLabel(activeInstance?.structure ?? templateWeeks);

    if (showArchived) {
      return SummaryCard(
        archived: true,
        icon: Icons.checklist_outlined,
        title: program.name,
        chips: [
          SummaryInfoChip(
            Icons.archive_outlined,
            'Archived ${program.archivedAt != null ? formatDate(program.archivedAt!) : ''}'.trim(),
          ),
        ],
        onTap: () => context.push(AppConstants.routeProgramDetail(program.id)),
        trailing: ArchivedRowActions(
          onRestore: () => _restore(context, ref),
        ),
      );
    }

    final card = SummaryCard(
      icon: Icons.checklist_outlined,
      leading: ProgramWeeksTile(
        weeks: stats.weeks,
        weeksDone: activeInstance == null ? null : stats.completedWeeks,
      ),
      title: program.name,
      subtitle: lastRun == null ? null : 'Last run ${formatDate(lastRun!)}',
      badge: program.isCopy
          ? CopiedFromBadge(
              isCopy: true,
              isImported: program.isImported,
              copiedFromUserId: program.copiedFromUserId,
              copiedFromDisplayName: program.copiedFromDisplayName,
              copiedFromSourceId: program.copiedFromProgramId,
            )
          : null,
      // A running program's description is old news to the lifter running
      // it; the row is about where they are.
      body: activeInstance != null || description == null || description.isEmpty ? null : Text(description),
      status: activeInstance == null ? null : _runStatus(activeInstance),
      // The created date lives on the program screen; here it wrapped onto a
      // line of its own and repeated the days chip's calendar icon.
      chips: programListChips(
        stats,
        // Days a week helps choose a program; once it's running, the status
        // line and the workouts done say more.
        daysPerWeek: activeInstance == null ? daysPerWeek : null,
        // The tile says how many weeks ("6wk").
        showWeeks: false,
      ),
      // A current program opens its run (what's done, what's next); the
      // template is View program in the ⋯ menu.
      onTap: () => context.push(
        activeInstance == null
            ? AppConstants.routeProgramDetail(program.id)
            : AppConstants.routeProgramInstanceDetail(activeInstance.id),
      ),
      trailing: IconButton(
        key: Key('program_actions_${program.id}'),
        icon: const Icon(Icons.more_horiz),
        // Named for its program, so a screen reader doesn't hear the same
        // "Show menu" on every row.
        tooltip: 'Actions for ${program.name}',
        onPressed: () => _showActions(context, ref),
      ),
    );

    final foot = activeInstance == null ? null : _footAction(context, ref, activeInstance);
    if (foot == null) return card;
    final tokens = NomorexTokens.of(context);
    // The row's foot, under a hairline from the text column: part of the
    // row to the eye, but beside its tap target rather than inside it, so
    // it's its own button to a screen reader and can't also open the run.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        const Divider(indent: 16 + NomorexSizes.iconTileSize + 12, endIndent: 16),
        Padding(
          // Lines up with the row's text, past the 32px icon tile and gap.
          padding: const EdgeInsets.fromLTRB(16 + NomorexSizes.iconTileSize + 12, 6, 16, 6),
          child: Align(
            alignment: Alignment.centerLeft,
            // Named for its program, like ⋯, so two current runs' buttons
            // don't sound the same; its own label would only say "Today ·
            // Day 3".
            child: Semantics(
              // Its own node, not merged into whatever encloses the row.
              container: true,
              label: foot.spoken,
              button: true,
              onTap: foot.onPressed,
              excludeSemantics: true,
              // Keyed by its role, like New program, so a change of style
              // swaps the button rather than animating between text styles.
              child: KeyedSubtree(
                key: ValueKey(primary),
                child: FilledButton.icon(
                  key: foot.key,
                  style: (primary ? const ButtonStyle() : tokens.secondaryButtonStyle).copyWith(
                    // The main between-sets action: a full 44px on a phone.
                    minimumSize: WidgetStatePropertyAll(
                      Size(0, isMobile(context) ? NomorexSizes.controlHeightLg : NomorexSizes.controlHeight),
                    ),
                  ),
                  onPressed: foot.onPressed,
                  icon: Icon(foot.icon, size: 18),
                  label: Text(foot.label, overflow: TextOverflow.ellipsis),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// What a current row's foot offers: today's workout on a training day
  /// (named for its session, "Today · Day 3"), Complete program once the
  /// schedule is over, and nothing on a rest day.
  ({Key key, String label, String spoken, IconData icon, VoidCallback onPressed})? _footAction(
    BuildContext context,
    WidgetRef ref,
    ProgramInstance current,
  ) {
    final workoutId = current.todaysWorkoutId;
    if (workoutId != null) {
      final done = current.todaysWorkoutsDone;
      final session = current.todaysWorkoutTitle;
      final label = done
          ? (session == null ? "Review today's workout" : 'Review today · $session')
          : (session == null ? "Today's workout" : 'Today · $session');
      return (
        key: Key('program_today_${program.id}'),
        label: label,
        spoken: [
          done ? "Review today's workout for ${program.name}" : "Today's workout for ${program.name}",
          ?session,
        ].join(', '),
        icon: done ? Icons.check : Icons.fitness_center_outlined,
        onPressed: () => context.push(AppConstants.routeWorkoutDetail(workoutId)),
      );
    }
    if (current.scheduleFinished) {
      return (
        key: Key('program_complete_${program.id}'),
        label: 'Complete program',
        spoken: 'Complete ${program.name}',
        icon: Icons.flag_outlined,
        onPressed: () => _complete(context, ref, current),
      );
    }
    return null;
  }

  /// The row's ⋯ actions. Start only for a program that isn't running; a
  /// current one, whose row opens the run, offers its template instead, and
  /// Complete once its schedule is over.
  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final current = run;
    final action = await showActionSheet<String>(
      context,
      title: program.name,
      actions: [
        if (current == null) const SheetAction('start', 'Start program', Icons.play_arrow_outlined),
        if (current != null) const SheetAction('view', 'View program', Icons.checklist_outlined),
        if (current != null && current.scheduleFinished)
          const SheetAction('complete', 'Complete program', Icons.flag_outlined),
        const SheetAction('edit', 'Edit', Icons.edit_outlined),
        const SheetAction('archive', 'Archive', Icons.archive_outlined, dividerBefore: true),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'start':
        await startProgramFlow(context, ref, program);
      case 'view':
        context.push(AppConstants.routeProgramDetail(program.id));
      case 'complete':
        await _complete(context, ref, current!);
      case 'edit':
        context.push(AppConstants.routeProgramEdit(program.id));
      case 'archive':
        await _archive(context, ref);
    }
  }

  /// Archives the program, with Undo. A running program asks first: archiving
  /// hides the program but doesn't stop the run, which would otherwise seem
  /// to vanish from this list while it carries on at Home.
  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    if (run != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Archive ${program.name}?'),
          content: const Text(
            "It's running. Archiving hides the program here, but the run carries on: "
            'its workouts stay on Home and in your history.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            // Neutral: archiving is reversible, and the orange belongs to
            // the page's main action.
            FilledButton(
              key: const Key('program_archive_confirm'),
              style: NomorexTokens.of(ctx).secondaryButtonStyle,
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Archive'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(programsProvider.notifier);
    try {
      await notifier.archiveProgram(program.id);
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
      messenger.showSnackBar(SnackBar(
        content: Text("Couldn't archive ${program.name}. Check your connection and try again."),
      ));
      return;
    }
    messenger.showSnackBar(SnackBar(
      content: Text('Archived ${program.name}'),
      // An action keeps a snackbar up until it's dismissed unless told not to.
      persist: false,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          try {
            await notifier.restoreProgram(program.id);
          } catch (e, st) {
            await Sentry.captureException(e, stackTrace: st);
            messenger.showSnackBar(SnackBar(
              content: Text("Couldn't restore ${program.name}. Find it under Archived."),
            ));
          }
        },
      ),
    ));
  }

  /// Marks a run whose schedule is over as complete, the same as the run
  /// screen's Complete program: it moves to program history.
  Future<void> _complete(BuildContext context, WidgetRef ref, ProgramInstance current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Complete ${program.name}?'),
        content: const Text('It will move to your program history. Your logged workouts are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('program_complete_confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(programInstancesProvider.notifier).completeProgramInstance(current.id);
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
      messenger.showSnackBar(SnackBar(
        content: Text("Couldn't complete ${program.name}. Check your connection and try again."),
      ));
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(programsProvider.notifier).restoreProgram(program.id);
    } catch (e, st) {
      await Sentry.captureException(e, stackTrace: st);
      messenger.showSnackBar(SnackBar(
        content: Text("Couldn't restore ${program.name}. Check your connection and try again."),
      ));
    }
  }

  /// "Week 2 of 6 · Day 3 today" while the run is under way, "Week 2 of 6 ·
  /// Rest day · next session tomorrow" on a rest day, "Schedule finished"
  /// once its last week has passed, and when it starts before that.
  ProgramRunStatus _runStatus(ProgramInstance run) {
    final today = run.today;
    final day = today?.day;
    String? todayLabel;
    if (day != null && !day.isRest) {
      // The foot's "Today · Day 3" already says it.
      todayLabel = run.todaysWorkoutId != null ? null : 'Day ${today!.dayInWeek} today';
    } else if (today != null) {
      // A rest day, or a date the week has no day for.
      final next = run.daysToNextSession;
      final rest = day != null ? 'Rest day' : 'No session today';
      todayLabel = switch (next) {
        null => rest,
        1 => '$rest · next session tomorrow',
        final n => '$rest · next session in $n days',
      };
    }
    return ProgramRunStatus(
      upcoming: isProgramUpcoming(run.startedAt),
      date: formatDate(run.startedAt),
      finished: run.scheduleFinished,
      week: today == null ? null : 'Week ${today.weekIndex + 1} of ${today.weekCount}',
      today: todayLabel,
    );
  }
}
