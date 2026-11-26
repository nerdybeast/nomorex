import 'package:material_ui/material_ui.dart';

import '../../core/constants/app_constants.dart';

/// A top-level place in the app: the three shell tabs, plus Profile and Admin,
/// which the wide-layout sidebar shows in its footer.
enum NavSection {
  home('Home', Icons.home_outlined, Icons.home, AppConstants.routeHome),
  training('Training', Icons.fitness_center_outlined, Icons.fitness_center, AppConstants.routeTraining),
  community('Community', Icons.public_outlined, Icons.public, AppConstants.routeCommunity),
  profile('Profile', Icons.person_outline, Icons.person, AppConstants.routeProfile),
  admin('Admin', Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, AppConstants.routeAdmin);

  const NavSection(this.label, this.icon, this.selectedIcon, this.route);

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Where the section starts: a shell tab, or a top-level route.
  final String route;

  /// The shell tabs, in the order every layout shows them. Must match the
  /// `StatefulShellRoute` branches in `app.dart`.
  static const tabs = [home, training, community];
}

/// What Training's switcher shows. Each view has its own path under
/// [AppConstants.routeTraining], so a link or back lands on the right one.
enum TrainingView {
  programs('Programs', 'programs', AppConstants.routePrograms),
  workouts('Workouts', 'workouts', AppConstants.routeWorkouts),
  prs('PRs', 'prs', AppConstants.routePrs);

  const TrainingView(this.label, this.segment, this.route);

  final String label;

  /// The `:view` path segment.
  final String segment;
  final String route;

  static TrainingView? fromSegment(String? segment) {
    for (final view in values) {
      if (view.segment == segment) return view;
    }
    return null;
  }
}

/// The Training view [location] belongs to, for breadcrumbs: a program's
/// screens are under Programs, and so on. Null outside Training.
TrainingView? trainingViewFor(String location) {
  bool under(String prefix) => location == prefix || location.startsWith('$prefix/');

  if (under(AppConstants.routePrograms) || under('/programs') || under('/program-instances')) {
    return TrainingView.programs;
  }
  if (under(AppConstants.routeWorkouts) || under('/workouts')) return TrainingView.workouts;
  if (under(AppConstants.routePrs) || under('/prs')) return TrainingView.prs;
  return null;
}

/// The section [location] belongs to, so the sidebar can keep it selected on
/// detail and edit screens (`/programs/:id` is under Training). Null for
/// routes outside every section, such as the AI import flow.
NavSection? navSectionFor(String location) {
  bool under(String prefix) => location == prefix || location.startsWith('$prefix/');

  if (under(AppConstants.routeHome)) return NavSection.home;
  if (under(AppConstants.routeTraining) || trainingViewFor(location) != null) return NavSection.training;
  if (under(AppConstants.routeCommunity) || under('/community')) return NavSection.community;
  if (under(AppConstants.routeProfile)) return NavSection.profile;
  if (under(AppConstants.routeAdmin)) return NavSection.admin;
  return null;
}

/// Something "New" (the phone bar's New sheet, the sidebar's menu) can start.
class NewItemAction {
  const NewItemAction(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

/// What "New" offers, in order. Both menus (the sidebar's and the phone bar's
/// New sheet) add [kAiImportAction] after these while imports are available.
const kNewItemActions = [
  NewItemAction('New personal best', Icons.emoji_events_outlined, AppConstants.routeAddPr),
  NewItemAction('New workout', Icons.fitness_center_outlined, AppConstants.routeWorkoutNew),
  NewItemAction('New program', Icons.checklist_outlined, AppConstants.routeProgramNew),
];

/// The AI import entry at the end of both "New" menus. Shown while
/// `aiImportAvailableProvider` is true: whenever a key can be added on this
/// device or the hosted alpha is switched on. The admin off switch now only
/// stops the hosted path; with no key, the import screen offers the settings.
const kAiImportAction = NewItemAction(
  'Import from photos or PDFs',
  Icons.document_scanner_outlined,
  AppConstants.routeAiImport,
);
