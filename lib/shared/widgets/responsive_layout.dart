import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Returns true if the current screen width is below the mobile breakpoint.
bool isMobile(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AppConstants.kMobileBreakpoint;

/// Vertical space the shell's centered "+" FAB occupies on mobile: the 56px
/// button, its 16px float margin, and 16px of breathing room.
const double kShellFabClearance = 88;

/// Extra bottom padding a shell-tab scrollable needs so its last item can
/// scroll clear of the shell FAB. Zero on wide layouts, where "New" lives in
/// the sidebar instead of floating over the content.
double shellFabClearance(BuildContext context) => isMobile(context) ? kShellFabClearance : 0;

/// The widest a list or detail screen's content gets. Wider windows get more
/// margin, not longer rows: past this a row's title and chevron drift too far
/// apart to read as one line.
const double kContentMaxWidth = 840;

/// Width of the wide-layout sidebar, expanded and collapsed to a rail, each
/// including its 1px border.
const double kSidebarWidth = 232;
const double kSidebarRailWidth = 76;

/// How wide the sidebar beside the current page is, so [contentInset] can
/// center content in the space that's left. `AppFrame` puts it above every
/// signed-in page on wide layouts; anywhere else (phones, dialogs, tests that
/// pump a bare screen) the sidebar takes no room.
class SidebarInset extends InheritedWidget {
  const SidebarInset({super.key, required this.width, required super.child});

  final double width;

  static double widthOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SidebarInset>()?.width ?? 0;

  static bool isPresent(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SidebarInset>() != null;

  @override
  bool updateShouldNotify(SidebarInset oldWidget) => oldWidget.width != width;
}

/// Whether a sidebar destination's own screen (Profile, Admin) should show a
/// back arrow. Beside the sidebar it doesn't need one: the sidebar is the way
/// back. On a phone, or anywhere without the sidebar, it does, so a page
/// opened on a wide window still has a way back once the window narrows.
bool showsBackForSidebarDestination(BuildContext context) =>
    isMobile(context) || !SidebarInset.isPresent(context);

/// Horizontal inset that keeps content at most [maxWidth] wide and centered
/// in the space beside the sidebar, never less than 16px. Applied as
/// scroll-view padding rather than a ConstrainedBox, so the scroll view
/// (wheel, scrollbar, drag) still spans the whole page.
double contentInset(BuildContext context, {double maxWidth = kContentMaxWidth}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < AppConstants.kMobileBreakpoint) return 16;
  final body = width - SidebarInset.widthOf(context);
  return math.max(16, (body - maxWidth) / 2);
}

/// Padding for a list or detail screen's scroll view: [contentInset] on the
/// sides, [top]/[bottom] as given.
EdgeInsets contentPadding(
  BuildContext context, {
  double top = 16,
  double bottom = 16,
  double maxWidth = kContentMaxWidth,
}) {
  final inset = contentInset(context, maxWidth: maxWidth);
  return EdgeInsets.fromLTRB(inset, top, inset, bottom);
}

/// Standard list padding on a shell tab, centered at [kContentMaxWidth] on
/// wide layouts, plus [shellFabClearance] at the bottom.
EdgeInsets shellListPadding(BuildContext context) =>
    contentPadding(context, bottom: 16 + shellFabClearance(context));
