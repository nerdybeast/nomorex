import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../models/workout.dart';
import '../providers/workouts_provider.dart';

/// Confirms via [showConfirmDialog], then hard-deletes [workout]'s whole group.
/// Only reachable from the Archived tab of the Workouts list — everywhere
/// else a workout is archived, not deleted.
Future<void> confirmAndDeleteWorkoutPermanently(
  BuildContext context,
  WidgetRef ref,
  Workout workout,
) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Delete workout permanently?',
    message:
        'This deletes "${workout.title}" and all of its logged sessions. This can\'t be undone.',
    confirmLabel: 'Delete',
  );
  if (!confirmed || !context.mounted) return;
  await ref.read(workoutsProvider.notifier).deleteWorkoutPermanently(workout);
}
