import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('New personal best'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(AppConstants.routeAddPr);
              },
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center_outlined),
              title: const Text('New workout'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(AppConstants.routeWorkoutNew);
              },
            ),
            ListTile(
              leading: const Icon(Icons.checklist_outlined),
              title: const Text('New program'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(AppConstants.routeProgramNew);
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
    final colorScheme = Theme.of(context).colorScheme;

    if (isMobile) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: NomorexSizes.navBarHeight,
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: 'Home',
                      selected: shell.currentIndex == 0,
                      onTap: () => shell.goBranch(0),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.checklist_outlined,
                      selectedIcon: Icons.checklist,
                      label: 'Programs',
                      selected: shell.currentIndex == 1,
                      onTap: () => shell.goBranch(1),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.fitness_center_outlined,
                      selectedIcon: Icons.fitness_center,
                      label: 'Workouts',
                      selected: shell.currentIndex == 2,
                      onTap: () => shell.goBranch(2),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.list_outlined,
                      selectedIcon: Icons.list,
                      label: 'My PRs',
                      selected: shell.currentIndex == 3,
                      onTap: () => shell.goBranch(3),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.public_outlined,
                      selectedIcon: Icons.public,
                      label: 'Community',
                      selected: shell.currentIndex == 4,
                      onTap: () => shell.goBranch(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          key: const Key('shell_add_fab'),
          heroTag: 'shellAddFab',
          onPressed: () => _showAddMenu(context),
          tooltip: 'Add',
          child: const Icon(Icons.add, size: 26),
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
              // Same key as the mobile FAB above: the two layout branches are
              // mutually exclusive, so only one is ever in the tree.
              key: const Key('shell_add_fab'),
              heroTag: 'shellAddFabRail',
              onPressed: () => _showAddMenu(context),
              mini: true,
              tooltip: 'Add',
              child: const Icon(Icons.add, size: 22),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: Text('Programs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: Text('Workouts'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list_outlined),
                selectedIcon: Icon(Icons.list),
                label: Text('My PRs'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.public_outlined),
                selectedIcon: Icon(Icons.public),
                label: Text('Community'),
              ),
            ],
          ),
          VerticalDivider(thickness: 1, width: 1, color: colorScheme.outlineVariant),
          Expanded(child: shell),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NomorexTokens.of(context).palette;
    // Selected: filled icon in primary-text, label in fg-1. Everything else
    // stays fg-3 — no pill or indicator behind the icon.
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            selected ? selectedIcon : icon,
            size: 20,
            color: selected ? palette.primaryText : palette.fg3,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: selected ? palette.fg1 : palette.fg3,
            ),
          ),
        ],
      ),
    );
  }
}
