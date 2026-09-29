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

/// Standard 16px list padding plus [shellFabClearance] at the bottom.
EdgeInsets shellListPadding(BuildContext context) =>
    EdgeInsets.fromLTRB(16, 16, 16, 16 + shellFabClearance(context));
