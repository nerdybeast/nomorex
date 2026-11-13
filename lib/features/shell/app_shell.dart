import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import 'nav_section.dart';

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
            for (final action in kNewItemActions)
              ListTile(
                leading: Icon(action.icon),
                title: Text(action.label),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push(action.route);
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
                  for (final (i, tab) in NavSection.tabs.indexed)
                    Expanded(
                      child: _NavItem(
                        icon: tab.icon,
                        selectedIcon: tab.selectedIcon,
                        label: tab.label,
                        selected: shell.currentIndex == i,
                        onTap: () => shell.goBranch(i),
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

    // Wide layouts: AppFrame, around every signed-in page, draws the sidebar.
    return shell;
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
    // A bare InkWell reads as plain text: say it's a button and which tab is
    // current, the way NavigationRail does on wide layouts. The subtree's own
    // semantics are replaced, so the tap action is re-declared here.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        focusColor: palette.bg3,
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
      ),
    );
  }
}
