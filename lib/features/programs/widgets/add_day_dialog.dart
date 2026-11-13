import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/sequential_naming.dart';
import '../models/program_week.dart';
import '../providers/program_detail_provider.dart';

/// Asks for a new day's title (defaulting to the next "Day N") and whether
/// it's a rest day, then adds it to the end of [week]. Returns whether a day
/// was added, once it's saved.
Future<bool> showAddDayDialog(
  BuildContext context,
  WidgetRef ref, {
  required String programId,
  required ProgramWeek week,
}) async {
  final defaultTitle = nextSequentialName(week.days.map((d) => d.title), 'Day');
  final controller = TextEditingController();
  var isRestDay = false;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('Add day'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Title', hintText: defaultTitle),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Rest day'),
              value: isRestDay,
              onChanged: (v) => setState(() => isRestDay = v),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    ),
  );
  if (result == true) {
    final typed = controller.text.trim();
    await ref.read(programDetailProvider(programId).notifier).addDay(
          week.id,
          title: typed.isEmpty ? defaultTitle : typed,
          isRestDay: isRestDay,
        );
    return true;
  }
  return false;
}
