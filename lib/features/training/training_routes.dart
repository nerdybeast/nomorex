import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../shell/nav_section.dart';
import 'screens/training_screen.dart';

/// The Training shell branch's routes. [lastView] is the view used last
/// (`TrainingViewNotifier.lastUsed`), which the bare `/shell/training`
/// reopens; the redirect waits for it, so a saved view isn't missed while it
/// loads.
List<RouteBase> trainingBranchRoutes(FutureOr<TrainingView> Function() lastView) => [
      GoRoute(
        path: AppConstants.routeTraining,
        redirect: (_, state) async =>
            state.uri.path == AppConstants.routeTraining ? (await lastView()).route : null,
      ),
      GoRoute(
        path: '${AppConstants.routeTraining}/:view',
        redirect: (_, state) =>
            TrainingView.fromSegment(state.pathParameters['view']) == null ? AppConstants.routePrograms : null,
        // One page key for every view: switching views keeps the same
        // TrainingScreen, with no transition and no lost state.
        pageBuilder: (_, state) => NoTransitionPage(
          key: const ValueKey('training'),
          child: TrainingScreen(view: TrainingView.fromSegment(state.pathParameters['view'])!),
        ),
      ),
    ];

/// Where the three lists lived before Training, redirected so old links and
/// bookmarks still land on the right view. Top-level routes, outside the shell.
final List<RouteBase> legacyTrainingRedirects = [
  for (final (from, to) in [
    (AppConstants.legacyRoutePrograms, AppConstants.routePrograms),
    (AppConstants.legacyRouteWorkouts, AppConstants.routeWorkouts),
    (AppConstants.legacyRoutePrs, AppConstants.routePrs),
  ])
    GoRoute(path: from, redirect: (_, _) => to),
];
