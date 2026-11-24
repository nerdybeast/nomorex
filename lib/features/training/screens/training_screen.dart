import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../personal_bests/screens/prs_view.dart';
import '../../programs/screens/programs_view.dart';
import '../../shell/nav_section.dart';
import '../../shell/providers/training_view_provider.dart';
import '../../workouts/screens/workouts_view.dart';

/// The Training tab: the user's programs, workouts and PRs behind a tab bar,
/// styled like Community's.
///
/// [view] comes from the path (`/shell/training/:view`), so a tab tap
/// navigates rather than holding state: back and links land on the right view.
/// The [TabController] only follows the route; the body is an [IndexedStack]
/// rather than a `TabBarView`, so there's no swipe that would change the view
/// without changing the URL.
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

class _TrainingScreenState extends ConsumerState<TrainingScreen>
    with SingleTickerProviderStateMixin {
  final _opened = <TrainingView>{};
  late final TabController _tabController = TabController(
    length: TrainingView.values.length,
    initialIndex: widget.view.index,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _remember();
  }

  @override
  void didUpdateWidget(TrainingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view != widget.view) {
      // Back, a link or the saved view moved the route: move the tab with it.
      if (_tabController.index != widget.view.index) {
        _tabController.animateTo(widget.view.index);
      }
      _remember();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        bottom: _CappedTabBar(
          tabBar: TabBar(
            key: const Key('training_view_switcher'),
            controller: _tabController,
            tabs: [
              for (final v in TrainingView.values)
                Tab(key: Key('training_view_${v.segment}'), text: v.label),
            ],
            onTap: (i) {
              final next = TrainingView.values[i];
              if (next != view) context.go(next.route);
            },
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

/// The Training switcher at its specified width: full width on a phone, and
/// beside the sidebar at most 420px, its labels packed from the page
/// content's left edge, so three short labels don't float hundreds of pixels
/// apart. The hairline
/// under it still spans the page.
class _CappedTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _CappedTabBar({required this.tabBar});

  final TabBar tabBar;

  @override
  Size get preferredSize => tabBar.preferredSize;

  @override
  Widget build(BuildContext context) {
    if (isMobile(context)) return tabBar;
    // Tabs sized to their labels and packed from the start, so "Programs"
    // begins on the content's left edge instead of centered in a 140px cell.
    final packed = TabBar(
      key: tabBar.key,
      controller: tabBar.controller,
      tabs: tabBar.tabs,
      onTap: tabBar.onTap,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(right: 32),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: NomorexTokens.of(context).palette.borderSubtle)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: contentInset(context)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: packed),
        ),
      ),
    );
  }
}
