import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/widgets/responsive_layout.dart';
import 'providers/sidebar_collapse_provider.dart';
import 'widgets/app_sidebar.dart';

/// Wraps every signed-in page. From 600px up it puts [AppSidebar] beside the
/// page, so navigation stays in place on detail and edit screens too; on a
/// phone it passes the page straight through, and `AppShell`'s bottom bar
/// handles navigation instead.
///
/// Keyboard: `[` collapses or expands the sidebar, `N` opens "New". Neither
/// fires while typing in a text field, with a modifier held, or while
/// something (a dialog, a sheet) is open above the pages.
class AppFrame extends ConsumerStatefulWidget {
  const AppFrame({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends ConsumerState<AppFrame> {
  final _newMenu = MenuController();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  bool get _isWide => MediaQuery.sizeOf(context).width >= AppConstants.kMobileBreakpoint;

  void _toggle() => ref.read(sidebarCollapseProvider.notifier).toggle(MediaQuery.sizeOf(context).width);

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent || !mounted || !_isWide) return false;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isControlPressed || keyboard.isMetaPressed || keyboard.isAltPressed) return false;
    // Something above the pages, such as a dialog, owns the keyboard.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return false;
    final focused = FocusManager.instance.primaryFocus?.context;
    if (focused != null &&
        (focused.widget is EditableText || focused.findAncestorWidgetOfExactType<EditableText>() != null)) {
      return false;
    }
    switch (event.character) {
      case '[':
        _toggle();
        return true;
      case 'n' || 'N':
        if (_newMenu.isOpen) return false;
        _newMenu.open();
        return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < AppConstants.kMobileBreakpoint) return widget.child;

    final collapsed = ref.watch(sidebarCollapseProvider.select((s) => s.isCollapsed(width)));
    final sidebarWidth = collapsed ? kSidebarRailWidth : kSidebarWidth;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The width animates; the contents switch straight to the target
        // layout and are clipped while the edge catches up, so nothing is
        // ever laid out at an in-between width.
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: sidebarWidth,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: sidebarWidth,
              maxWidth: sidebarWidth,
              child: AppSidebar(
                location: widget.location,
                collapsed: collapsed,
                newMenu: _newMenu,
                onToggle: _toggle,
              ),
            ),
          ),
        ),
        // Its own semantics container: each page's route barrier blocks the
        // semantics of everything painted before it in the same container,
        // which without this would hide the whole sidebar from screen readers.
        Expanded(
          child: Semantics(
            container: true,
            child: SidebarInset(width: sidebarWidth, child: widget.child),
          ),
        ),
      ],
    );
  }
}
