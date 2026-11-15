import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../personal_bests/screens/prs_view.dart';
import '../../programs/screens/programs_view.dart';
import '../../shell/nav_section.dart';
import '../../shell/providers/training_view_provider.dart';
import '../../workouts/screens/workouts_view.dart';

/// The Training tab: the user's programs, workouts and PRs behind one switcher.
///
/// [view] comes from the path (`/shell/training/:view`), so the switcher
/// navigates rather than holding state: back and links land on the right view.
/// The route keeps one page for every view, so this widget stays mounted
/// across a switch and the [IndexedStack] keeps each view's search and scroll.
/// A view is built the first time it's shown, so opening Training doesn't
/// load all three lists.
class TrainingScreen extends ConsumerStatefulWidget {
  const TrainingScreen({super.key, required this.view});

  final TrainingView view;

  @override
  ConsumerState<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends ConsumerState<TrainingScreen> {
  final _opened = <TrainingView>{};

  @override
  void initState() {
    super.initState();
    _remember();
  }

  @override
  void didUpdateWidget(TrainingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view) _remember();
  }

  // After the frame: providers can't change while widgets are building.
  void _remember() {
    final view = widget.view;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(trainingViewProvider.notifier).set(view);
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    _opened.add(view);
    final isRefreshing = switch (view) {
      TrainingView.programs => ProgramsView.isRefreshing(ref),
      TrainingView.workouts => WorkoutsView.isRefreshing(ref),
      TrainingView.prs => PrsView.isRefreshing(ref),
    };
    final history = switch (view) {
      TrainingView.programs => (AppConstants.routeProgramHistory, 'Program history'),
      TrainingView.workouts => (AppConstants.routeWorkoutHistory, 'Workout history'),
      TrainingView.prs => null,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Training'),
        actions: [
          IconButton(
            icon: isRefreshing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: isRefreshing
                ? null
                : () => switch (view) {
                      TrainingView.programs => ProgramsView.refresh(ref),
                      TrainingView.workouts => WorkoutsView.refresh(ref),
                      TrainingView.prs => PrsView.refresh(ref),
                    },
          ),
          if (history != null)
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: history.$2,
              onPressed: () => context.push(history.$1),
            ),
          // On wide layouts the sidebar's account card opens Profile.
          if (isMobile(context))
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => context.push(AppConstants.routeProfile),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          // Lined up with the list's left edge; full width on a phone, capped
          // at 420px on wider screens so the three segments stay compact.
          child: Padding(
            padding: contentPadding(context, top: 0, bottom: 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<TrainingView>(
                key: const Key('training_view_switcher'),
                showSelectedIcon: false,
                segments: [
                  for (final v in TrainingView.values)
                    ButtonSegment(value: v, label: Text(v.label, key: Key('training_view_${v.segment}'))),
                ],
                selected: {view},
                    onSelectionChanged: (s) => context.go(s.first.route),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: view.index,
        children: [
          for (final v in TrainingView.values)
            if (!_opened.contains(v))
              const SizedBox.shrink()
            else
              switch (v) {
                TrainingView.programs => const ProgramsView(),
                TrainingView.workouts => const WorkoutsView(),
                TrainingView.prs => const PrsView(),
              },
        ],
      ),
    );
  }
}
