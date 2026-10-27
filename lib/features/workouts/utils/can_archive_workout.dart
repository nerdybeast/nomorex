import '../models/workout.dart';

/// Whether the Archive action is offered for [workout]: never while a session
/// is running or paused (finish or discard it first), never for a workout
/// materialized from a program (it lives on the program run's screen, not the
/// Workouts list), and not again once it's archived.
bool canArchiveWorkout(Workout workout) =>
    workout.programInstanceId == null &&
    !workout.isArchived &&
    workout.status != 'in_progress' &&
    workout.status != 'paused';
