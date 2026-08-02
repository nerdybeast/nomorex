import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../workouts/providers/workouts_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _showAddMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('New Personal Best'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(AppConstants.routeAddPr);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center_outlined),
              title: const Text('New Workout'),
              onTap: () async {
                Navigator.pop(ctx);
                final id = await ref.read(workoutsProvider.notifier).createWorkout();
                if (context.mounted) context.push(AppConstants.routeWorkoutEdit(id));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.sizeOf(context).width < AppConstants.kMobileBreakpoint;

    if (isMobile) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: Icon(
                  shell.currentIndex == 0 ? Icons.home : Icons.home_outlined,
                ),
                onPressed: () => shell.goBranch(0),
                tooltip: 'Home',
              ),
              const SizedBox(width: 48),
              IconButton(
                icon: Icon(
                  shell.currentIndex == 1 ? Icons.list : Icons.list_outlined,
                ),
                onPressed: () => shell.goBranch(1),
                tooltip: 'My PRs',
              ),
              IconButton(
                icon: Icon(
                  shell.currentIndex == 2
                      ? Icons.fitness_center
                      : Icons.fitness_center_outlined,
                ),
                onPressed: () => shell.goBranch(2),
                tooltip: 'Workouts',
              ),
              IconButton(
                icon: Icon(
                  shell.currentIndex == 3 ? Icons.public : Icons.public_outlined,
                ),
                onPressed: () => shell.goBranch(3),
                tooltip: 'Community',
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: 'shellAddFab',
          onPressed: () => _showAddMenu(context, ref),
          tooltip: 'Add',
          child: const Icon(Icons.add),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      );
    }

    // Wide layout: NavigationRail on left
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: shell.goBranch,
            labelType: NavigationRailLabelType.all,
            leading: FloatingActionButton(
              heroTag: 'shellAddFabRail',
              onPressed: () => _showAddMenu(context, ref),
              mini: true,
              tooltip: 'Add',
              child: const Icon(Icons.add),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list_outlined),
                selectedIcon: Icon(Icons.list),
                label: Text('My PRs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: Text('Workouts'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.public_outlined),
                selectedIcon: Icon(Icons.public),
                label: Text('Community'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
