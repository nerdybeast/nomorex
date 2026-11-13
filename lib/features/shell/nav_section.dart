import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// A top-level place in the app: the five shell tabs, plus Profile and Admin,
/// which the wide-layout sidebar shows in its footer.
enum NavSection {
  home('Home', Icons.home_outlined, Icons.home, AppConstants.routeHome),
  programs('Programs', Icons.checklist_outlined, Icons.checklist, AppConstants.routePrograms),
  workouts('Workouts', Icons.fitness_center_outlined, Icons.fitness_center, AppConstants.routeWorkouts),
  prs('My PRs', Icons.list_outlined, Icons.list, AppConstants.routePrs),
  community('Community', Icons.public_outlined, Icons.public, AppConstants.routeCommunity),
  profile('Profile', Icons.person_outline, Icons.person, AppConstants.routeProfile),
  admin('Admin', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, AppConstants.routeAdmin);

  const NavSection(this.label, this.icon, this.selectedIcon, this.route);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Where the section starts: a shell tab, or a top-level route.
  final String route;

  /// The shell tabs, in the order every layout shows them.
  static const tabs = [home, programs, workouts, prs, community];
}

/// The section [location] belongs to, so the sidebar can keep it selected on
/// detail and edit screens (`/programs/:id` is under Programs). Null for
/// routes outside every section, such as the AI import flow.
NavSection? navSectionFor(String location) {
  bool under(String prefix) => location == prefix || location.startsWith('$prefix/');

  if (under(AppConstants.routeHome)) return NavSection.home;
  if (under(AppConstants.routePrograms) || under('/programs') || under('/program-instances')) {
    return NavSection.programs;
  }
  if (under(AppConstants.routeWorkouts) || under('/workouts')) return NavSection.workouts;
  if (under(AppConstants.routePrs) || under('/prs')) return NavSection.prs;
  if (under(AppConstants.routeCommunity) || under('/community')) return NavSection.community;
  if (under(AppConstants.routeProfile)) return NavSection.profile;
  if (under(AppConstants.routeAdmin)) return NavSection.admin;
  return null;
}

/// Something "New" (the phone FAB's sheet, the sidebar's menu) can start.
class NewItemAction {
  const NewItemAction(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

/// What "New" offers, in order. The sidebar's menu adds AI import after these
/// while imports are switched on.
const kNewItemActions = [
  NewItemAction('New personal best', Icons.emoji_events_outlined, AppConstants.routeAddPr),
  NewItemAction('New workout', Icons.fitness_center_outlined, AppConstants.routeWorkoutNew),
  NewItemAction('New program', Icons.checklist_outlined, AppConstants.routeProgramNew),
];
