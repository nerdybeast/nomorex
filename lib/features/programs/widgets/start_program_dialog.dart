import 'package:flutter/material.dart';
import '../../../core/utils/date_formatter.dart';
import '../utils/program_day_date.dart';

/// Asks for a program's start date. Returns the chosen date, or null if the
/// user cancelled. Shared by starting your own program (ProgramDetailScreen)
/// and starting a copy of someone else's (CommunityProgramDetailScreen), so
/// both flows schedule identically.
Future<DateTime?> showStartProgramDialog(
  BuildContext context, {
  required int dayCount,
}) async {
  var startDate = DateTime.now();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Start Program'),
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
            if (dayCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Ends around ${formatDate(programDayDate(startDate, dayCount - 1))}.',
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
