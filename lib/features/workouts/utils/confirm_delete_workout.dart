import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../models/workout.dart';
import '../providers/workouts_provider.dart';

/// Confirms via [showConfirmDialog], then deletes [workout] and (if
/// [navigateToListOnDelete]) returns to the Workouts list. Shared by the
/// Workouts list's overflow menu, WorkoutDetailScreen, and EditWorkoutScreen
/// so all three go through one confirm+delete+navigate flow.
Future<void> confirmAndDeleteWorkout(
  BuildContext context,
  WidgetRef ref,
  Workout workout, {
  bool navigateToListOnDelete = false,
}) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Delete workout?',
    message: 'This permanently deletes "${workout.title}" and all of its exercises and sets.',
    confirmLabel: 'Delete',
  );
  if (!confirmed || !context.mounted) return;
  await ref.read(workoutsProvider.notifier).deleteWorkout(workout.id);
  if (navigateToListOnDelete && context.mounted) {
    context.go(AppConstants.routeWorkouts);
  }
}
