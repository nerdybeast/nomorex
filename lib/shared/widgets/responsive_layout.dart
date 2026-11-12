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
/// scroll clear of the shell FAB. Zero on wide layouts, where the "+" lives
/// in the NavigationRail instead of floating over the content.
double shellFabClearance(BuildContext context) => isMobile(context) ? kShellFabClearance : 0;

/// The widest a list or detail screen's content gets. Wider windows get more
/// margin, not longer rows: past this a row's title and chevron drift too far
/// apart to read as one line.
const double kContentMaxWidth = 840;

/// Width of the shell's NavigationRail plus its divider on wide layouts.
const double kShellRailWidth = 81;

/// Horizontal inset that keeps content at most [kContentMaxWidth] wide and
/// centered, never less than 16px. Applied as scroll-view padding rather than
/// a ConstrainedBox, so the scroll view (wheel, scrollbar, drag) still spans
/// the whole window. [inShell] accounts for the rail beside a shell tab.
double contentInset(BuildContext context, {bool inShell = false, double maxWidth = kContentMaxWidth}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width < AppConstants.kMobileBreakpoint) return 16;
  final body = width - (inShell ? kShellRailWidth : 0);
  return math.max(16, (body - maxWidth) / 2);
}

/// Padding for a list or detail screen's scroll view: [contentInset] on the
/// sides, [top]/[bottom] as given.
EdgeInsets contentPadding(
  BuildContext context, {
  double top = 16,
  double bottom = 16,
  bool inShell = false,
  double maxWidth = kContentMaxWidth,
}) {
  final inset = contentInset(context, inShell: inShell, maxWidth: maxWidth);
  return EdgeInsets.fromLTRB(inset, top, inset, bottom);
}

/// Standard list padding on a shell tab, centered at [kContentMaxWidth] on
/// wide layouts, plus [shellFabClearance] at the bottom.
EdgeInsets shellListPadding(BuildContext context) =>
    contentPadding(context, bottom: 16 + shellFabClearance(context), inShell: true);
