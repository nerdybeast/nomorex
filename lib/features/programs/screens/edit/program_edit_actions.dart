import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../../models/program.dart';
import '../../models/program_day.dart';
import '../../models/program_week.dart';
import '../../providers/program_detail_provider.dart';
import '../../utils/program_edit_summary.dart';
import 'widgets/edit_chrome.dart';

enum _WeekAction { duplicate, rename, moveUp, moveDown, delete }

enum _DayAction { duplicate, copy, rename, restDay, moveUp, moveDown, delete }

/// The ⋯ menu for a week. [onDeleted] runs after the week is gone, so a
/// screen showing it can leave.
Future<void> showWeekActions(
  BuildContext context,
  WidgetRef ref, {
  required Program program,
  required ProgramWeek week,
  VoidCallback? onDeleted,
}) async {
  final index = program.weeks.indexWhere((w) => w.id == week.id);
  final action = await showActionSheet<_WeekAction>(
    context,
    title: weekTitle(week),
    actions: [
      const SheetAction(_WeekAction.duplicate, 'Duplicate week', Icons.content_copy_outlined),
      const SheetAction(_WeekAction.rename, 'Rename', Icons.edit_outlined),
      if (index > 0) const SheetAction(_WeekAction.moveUp, 'Move earlier', Icons.arrow_upward),
      if (index < program.weeks.length - 1) const SheetAction(_WeekAction.moveDown, 'Move later', Icons.arrow_downward),
      const SheetAction(_WeekAction.delete, 'Delete week', Icons.delete_outline, danger: true),
    ],
  );
  if (action == null || !context.mounted) return;
  final notifier = ref.read(programDetailProvider(program.id).notifier);

  switch (action) {
    case _WeekAction.duplicate:
      try {
        await notifier.duplicateWeek(week.id);
        if (context.mounted) {
          showEditSnack(context, 'Week ${week.weekNumber + 1} added as a copy of Week ${week.weekNumber}');
        }
      } catch (_) {
        if (context.mounted) showEditSnack(context, "Couldn't duplicate the week. Try again.");
      }
    case _WeekAction.rename:
      final label = await showRenameDialog(
        context,
        title: 'Rename Week ${week.weekNumber}',
        label: 'Label',
        hint: 'e.g. Loading Week 2/6',
        initial: week.label,
      );
      if (label != null) await notifier.updateWeekMeta(week.id, label: label);
    case _WeekAction.moveUp || _WeekAction.moveDown:
      final ids = program.weeks.map((w) => w.id).toList();
      final to = action == _WeekAction.moveUp ? index - 1 : index + 1;
      ids
        ..removeAt(index)
        ..insert(to, week.id);
      await notifier.reorderWeeks(ids);
    case _WeekAction.delete:
      final days = week.days.length;
      if (days > 0) {
        final confirmed = await showConfirmDialog(
          context,
          title: 'Delete week?',
          message: 'This will also delete its $days ${days == 1 ? 'day' : 'days'}.',
          confirmLabel: 'Delete',
        );
        if (!confirmed) return;
      }
      await notifier.removeWeek(week.id);
      onDeleted?.call();
  }
}

/// The ⋯ menu for a day. [onDeleted] runs after the day is gone.
Future<void> showDayActions(
  BuildContext context,
  WidgetRef ref, {
  required Program program,
  required ProgramWeek week,
  required ProgramDay day,
  VoidCallback? onDeleted,
}) async {
  final index = week.days.indexWhere((d) => d.id == day.id);
  final action = await showActionSheet<_DayAction>(
    context,
    title: day.title,
    actions: [
      const SheetAction(_DayAction.duplicate, 'Duplicate day', Icons.content_copy_outlined),
      if (program.weeks.length > 1)
        const SheetAction(_DayAction.copy, 'Copy to other weeks…', Icons.library_add_outlined),
      const SheetAction(_DayAction.rename, 'Rename', Icons.edit_outlined),
      SheetAction(
        _DayAction.restDay,
        day.isRestDay ? 'Make it a training day' : 'Make it a rest day',
        day.isRestDay ? Icons.fitness_center_outlined : Icons.bedtime_outlined,
      ),
      if (index > 0) const SheetAction(_DayAction.moveUp, 'Move earlier', Icons.arrow_upward),
      if (index < week.days.length - 1) const SheetAction(_DayAction.moveDown, 'Move later', Icons.arrow_downward),
      const SheetAction(_DayAction.delete, 'Delete day', Icons.delete_outline, danger: true),
    ],
  );
  if (action == null || !context.mounted) return;
  final notifier = ref.read(programDetailProvider(program.id).notifier);

  switch (action) {
    case _DayAction.duplicate:
      try {
        await notifier.duplicateDay(day.id);
        if (context.mounted) showEditSnack(context, '${day.title} duplicated at the end of ${weekTitle(week)}');
      } catch (_) {
        if (context.mounted) showEditSnack(context, "Couldn't duplicate the day. Try again.");
      }
    case _DayAction.copy:
      final targets = await _pickWeeks(context, program: program, exclude: week.id, dayTitle: day.title);
      if (targets == null || targets.isEmpty || !context.mounted) return;
      try {
        await notifier.copyDay(day.id, targets);
        final numbers = [
          for (final w in program.weeks)
            if (targets.contains(w.id)) w.weekNumber,
        ];
        if (context.mounted) showEditSnack(context, '${day.title} copied to ${_weekList(numbers)}');
      } catch (_) {
        if (context.mounted) showEditSnack(context, "Couldn't copy the day. Try again.");
      }
    case _DayAction.rename:
      final title = await showRenameDialog(context, title: 'Rename day', label: 'Title', initial: day.title);
      if (title != null && title.isNotEmpty) await notifier.updateDayMeta(day.id, title: title);
    case _DayAction.restDay:
      if (!day.isRestDay && day.exercises.isNotEmpty) {
        final confirmed = await showConfirmDialog(
          context,
          title: 'Make it a rest day?',
          message: 'Its exercises stay, but a rest day is shown without them.',
          confirmLabel: 'Make rest day',
        );
        if (!confirmed) return;
      }
      await notifier.updateDayMeta(day.id, isRestDay: !day.isRestDay);
    case _DayAction.moveUp || _DayAction.moveDown:
      final ids = week.days.map((d) => d.id).toList();
      final to = action == _DayAction.moveUp ? index - 1 : index + 1;
      ids
        ..removeAt(index)
        ..insert(to, day.id);
      await notifier.reorderDays(ids);
    case _DayAction.delete:
      final count = day.exercises.length;
      if (count > 0) {
        final confirmed = await showConfirmDialog(
          context,
          title: 'Delete day?',
          message: 'This will also delete its $count ${count == 1 ? 'exercise' : 'exercises'}.',
          confirmLabel: 'Delete',
        );
        if (!confirmed) return;
      }
      await notifier.removeDay(day.id);
      onDeleted?.call();
  }
}

/// "Week 2", "Weeks 2 and 3", "Weeks 2, 3 and 4".
String _weekList(List<int> numbers) {
  if (numbers.length == 1) return 'Week ${numbers.single}';
  final head = numbers.sublist(0, numbers.length - 1).join(', ');
  return 'Weeks $head and ${numbers.last}';
}

/// A checklist of the program's other weeks. Returns the chosen week ids in
/// program order, or null when cancelled.
Future<List<String>?> _pickWeeks(
  BuildContext context, {
  required Program program,
  required String exclude,
  required String dayTitle,
}) {
  final chosen = <String>{};
  return showModalBottomSheet<List<String>>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text('Copy $dayTitle to', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('It goes at the end of each week you pick.', style: Theme.of(ctx).textTheme.bodySmall),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final w in program.weeks)
                    if (w.id != exclude)
                      CheckboxListTile(
                        key: ValueKey('copy_to_${w.id}'),
                        value: chosen.contains(w.id),
                        title: Text(weekTitle(w)),
                        subtitle: Text(weekSummary(w)),
                        onChanged: (v) => setState(() => v == true ? chosen.add(w.id) : chosen.remove(w.id)),
                      ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                key: const Key('copy_day_confirm'),
                onPressed: chosen.isEmpty
                    ? null
                    : () => Navigator.pop(ctx, [
                          for (final w in program.weeks)
                            if (chosen.contains(w.id)) w.id,
                        ]),
                child: Text(chosen.isEmpty ? 'Pick a week' : 'Copy to ${chosen.length} ${chosen.length == 1 ? 'week' : 'weeks'}'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Opens [week] in the phone editor, replacing the current week or day so
/// back still goes up one level.
void replaceWithWeek(BuildContext context, String programId, String weekId) =>
    context.replace(AppConstants.routeProgramEditWeek(programId, weekId));

void replaceWithDay(BuildContext context, String programId, String dayId) =>
    context.replace(AppConstants.routeProgramEditDay(programId, dayId));
