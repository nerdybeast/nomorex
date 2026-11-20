import 'package:material_ui/material_ui.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/summary_card.dart';
import '../utils/program_day_date.dart';

/// Asks for a program's start date. Returns the chosen date, or null if the
/// user cancelled. Shared by starting your own program (ProgramDetailScreen)
/// and starting a copy of someone else's (CommunityProgramDetailScreen), so
/// both flows schedule identically.
///
/// [lastDayOffset] is the program's last day (`Program.lastDayOffset`), for
/// the "ends around" date; null when it has no days. [workoutCount], when
/// given, says up front what starting does: it puts that many workouts on
/// the calendar.
Future<DateTime?> showStartProgramDialog(
  BuildContext context, {
  required int? lastDayOffset,
  int? workoutCount,
}) async {
  var startDate = DateTime.now();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Start program'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(formatDate(startDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
                );
                if (picked != null) setState(() => startDate = picked);
              },
            ),
            if (lastDayOffset != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  workoutCount != null && workoutCount > 0
                      ? '${pluralize(workoutCount, 'workout')}, ends around ${formatDate(programDayDate(startDate, lastDayOffset))}.'
                      : 'Ends around ${formatDate(programDayDate(startDate, lastDayOffset))}.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start')),
        ],
      ),
    ),
  );
  return confirmed == true ? startDate : null;
}
