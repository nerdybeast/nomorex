import 'package:flutter/material.dart';
import '../../../core/utils/weight_converter.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';
import '../utils/set_builder_parser.dart';

/// Editable list of sets for a single exercise, plus add controls.
class SetEditor extends StatelessWidget {
  const SetEditor({
    super.key,
    required this.exercise,
    required this.unit,
    required this.onAddPercentageSets,
    required this.onAddAbsoluteSet,
    required this.onDeleteSet,
  });

  final WorkoutExercise exercise;
  final String unit;
  final void Function(List<ParsedSet>) onAddPercentageSets;
  final VoidCallback onAddAbsoluteSet;
  final void Function(String setId) onDeleteSet;

  Future<void> _showSetBuilder(BuildContext context) async {
    final controller = TextEditingController();
    try {
      String? error;
      await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Add sets'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'e.g. 4 x 2 @ 65-68-71-68',
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('A single percentage (3 x 5 @ 80) applies to all sets.',
                    style: TextStyle(fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  try {
                    final parsed = parseSetBuilder(controller.text);
                    onAddPercentageSets(parsed);
                    Navigator.pop(ctx);
                  } on FormatException catch (e) {
                    setState(() => error = e.message);
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final s in exercise.sets)
          _SetRow(
            set: s,
            unit: unit,
            onDelete: () => onDeleteSet(s.id),
          ),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _showSetBuilder(context),
              icon: const Icon(Icons.add),
              label: const Text('Add sets (%)'),
            ),
            TextButton.icon(
              onPressed: onAddAbsoluteSet,
              icon: const Icon(Icons.add),
              label: const Text('Add set (weight)'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.set,
    required this.unit,
    required this.onDelete,
  });

  final WorkoutSet set;
  final String unit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isPct = set.weightMode == 'percentage';
    final valueLabel = isPct
        ? '${set.percentage?.toStringAsFixed(0) ?? '?'}%'
        : (set.absoluteWeightKg != null
            ? formatWeight(set.absoluteWeightKg!, unit)
            : '? $unit');
    return ListTile(
      dense: true,
      leading: Text('${set.targetReps ?? '-'} reps'),
      title: Text(isPct ? '$valueLabel of 1RM' : valueLabel),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: onDelete,
      ),
    );
  }
}
