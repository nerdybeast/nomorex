import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

part 'sidebar_collapse_provider.g.dart';

/// Whether the wide-layout sidebar is collapsed to a rail, remembered
/// separately for tablet widths and for laptop/desktop widths.
@immutable
class SidebarCollapseState {
  const SidebarCollapseState({this.collapsedWide = false, this.collapsedTablet = true});

  /// At [AppConstants.kSidebarExpandedBreakpoint] and wider. Opens expanded.
  final bool collapsedWide;

  /// Between [AppConstants.kMobileBreakpoint] and the expanded breakpoint.
  /// Opens collapsed, since a tablet has less room to give the page.
  final bool collapsedTablet;

  static bool isTabletWidth(double width) => width < AppConstants.kSidebarExpandedBreakpoint;

  bool isCollapsed(double width) => isTabletWidth(width) ? collapsedTablet : collapsedWide;

  @override
  bool operator ==(Object other) =>
      other is SidebarCollapseState &&
      other.collapsedWide == collapsedWide &&
      other.collapsedTablet == collapsedTablet;

  @override
  int get hashCode => Object.hash(collapsedWide, collapsedTablet);
}

/// The sidebar's collapsed state. Saved on the device rather than in the
/// profile: it's about this screen, not the person.
///
/// Starts from the defaults and replaces them once the saved choice loads. If
/// the device can't store it (or in widget tests, where there's no platform
/// plugin), the defaults simply stay.
@Riverpod(keepAlive: true)
class SidebarCollapseNotifier extends _$SidebarCollapseNotifier {
  static const _wideKey = 'sidebar_collapsed_wide';
  static const _tabletKey = 'sidebar_collapsed_tablet';

  /// Set once the user toggles, so a slow first load can't undo their click.
  bool _touched = false;

  @override
  SidebarCollapseState build() {
    _load();
    return const SidebarCollapseState();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!ref.mounted || _touched) return;
      state = SidebarCollapseState(
        collapsedWide: prefs.getBool(_wideKey) ?? false,
        collapsedTablet: prefs.getBool(_tabletKey) ?? true,
      );
    } catch (_) {
      // No storage: keep the defaults.
    }
  }

  /// Collapses or expands the sidebar for the side of the breakpoint that
  /// [width] is on.
  Future<void> toggle(double width) async {
    _touched = true;
    final tablet = SidebarCollapseState.isTabletWidth(width);
    state = tablet
        ? SidebarCollapseState(collapsedWide: state.collapsedWide, collapsedTablet: !state.collapsedTablet)
        : SidebarCollapseState(collapsedWide: !state.collapsedWide, collapsedTablet: state.collapsedTablet);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(tablet ? _tabletKey : _wideKey, tablet ? state.collapsedTablet : state.collapsedWide);
    } catch (_) {
      // Not saved; the toggle still applies for this session.
    }
  }
}
