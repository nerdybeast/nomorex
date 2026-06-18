import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';

class AppShell extends StatelessWidget {
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
              title: const Text('New Personal Best'),
              onTap: () {
                Navigator.pop(ctx);
                context.push(AppConstants.routeAddPr);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < AppConstants.kMobileBreakpoint;

    if (isMobile) {
      return Scaffold(
        body: shell,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
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
              const SizedBox(width: 48), // space for FAB notch
              IconButton(
                icon: Icon(
                  shell.currentIndex == 1 ? Icons.list : Icons.list_outlined,
                ),
                onPressed: () => shell.goBranch(1),
                tooltip: 'My PRs',
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddMenu(context),
          tooltip: 'Add',
          child: const Icon(Icons.add),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
              onPressed: () => _showAddMenu(context),
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
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
