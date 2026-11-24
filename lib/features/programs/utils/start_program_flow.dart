import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../models/program.dart';
import '../providers/program_instances_provider.dart';
import '../widgets/start_program_dialog.dart';
import 'program_stats.dart';

/// How many workouts starting [program] puts on the calendar.
int programWorkoutCount(Program program) => templateStats(program.weeks.map(StatsWeek.fromWeek).toList()).workouts;

/// Starts a run of [program]: asks for the start date, calls `start_program`,
/// and opens the new run. Shared by the program screen's Start program button
/// ([replaceRoute], so back doesn't return to the template) and the Programs
/// list's ⋯ menu. A failure says so in a snackbar with Retry; the raw error
/// goes to Sentry, not the screen, since it can carry database details.
Future<void> startProgramFlow(
  BuildContext context,
  WidgetRef ref,
  Program program, {
  bool replaceRoute = false,
}) async {
  final startDate = await showStartProgramDialog(
    context,
    lastDayOffset: program.lastDayOffset,
    workoutCount: programWorkoutCount(program),
  );
  if (startDate == null || !context.mounted) return;

  try {
    final instanceId = await ref.read(programInstancesProvider.notifier).startProgram(program.id, startDate);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Program started')));
    final route = AppConstants.routeProgramInstanceDetail(instanceId);
    replaceRoute ? context.pushReplacement(route) : context.push(route);
  } catch (e, st) {
    await Sentry.captureException(e, stackTrace: st);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text("Couldn't start the program. Check your connection and try again."),
      persist: false,
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () => startProgramFlow(context, ref, program, replaceRoute: replaceRoute),
      ),
    ));
  }
}
