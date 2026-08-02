import 'package:flutter/material.dart';
import '../../../core/utils/weight_converter.dart';
import '../models/workout_exercise.dart';
import '../models/workout_set.dart';
import '../utils/parsed_set.dart';

/// Editable list of sets for a single exercise, plus add controls.
class SetEditor extends StatelessWidget {
  const SetEditor({
    super.key,
    required this.exercise,
    required this.unit,
    required this.onAddPercentageSets,
    required this.onAddAbsoluteSets,
    required this.onDeleteSet,
  });

  final WorkoutExercise exercise;
  final String unit;
  final void Function(List<ParsedSet>) onAddPercentageSets;
  final void Function(int sets, int reps, double weightKg) onAddAbsoluteSets;
  final void Function(String setId) onDeleteSet;

  Future<void> _showPercentageSetDialog(BuildContext context) async {
    var sets = 1;
    var reps = 1;
    var percentages = <double>[70];

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add sets (%)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _NumberField(
                  label: 'Sets',
                  value: sets.toDouble(),
                  min: 1,
                  step: 1,
                  decimals: 0,
                  onChanged: (v) => setState(() {
                    final newSets = v.round();
                    if (newSets > percentages.length) {
                      percentages = [
                        ...percentages,
                        for (var i = percentages.length; i < newSets; i++)
                          percentages.last,
                      ];
                    } else if (newSets < percentages.length) {
                      percentages = percentages.sublist(0, newSets);
                    }
                    sets = newSets;
                  }),
                ),
                _NumberField(
                  label: 'Reps',
                  value: reps.toDouble(),
                  min: 1,
                  step: 1,
                  decimals: 0,
                  onChanged: (v) => setState(() => reps = v.round()),
                ),
                const SizedBox(height: 8),
                // One stepper per set (rather than a single shared value) so
                // wave-loading (a different %1RM per set) stays possible.
                for (var i = 0; i < percentages.length; i++)
                  _NumberField(
                    label: 'Set ${i + 1} %1RM',
                    value: percentages[i],
                    min: 0,
                    step: 5,
                    decimals: 0,
                    onChanged: (v) => setState(() => percentages[i] = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                onAddPercentageSets([
                  for (final p in percentages) ParsedSet(reps, p),
                ]);
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAbsoluteSetDialog(BuildContext context) async {
    var sets = 1;
    var reps = 1;
    var weightDisplay = 0.0;
    final step = unit == 'lbs' ? 5.0 : 2.5;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add sets (weight)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NumberField(
                label: 'Sets',
                value: sets.toDouble(),
                min: 1,
                step: 1,
                decimals: 0,
                onChanged: (v) => setState(() => sets = v.round()),
              ),
              _NumberField(
                label: 'Reps',
                value: reps.toDouble(),
                min: 1,
                step: 1,
                decimals: 0,
                onChanged: (v) => setState(() => reps = v.round()),
              ),
              _NumberField(
                label: 'Weight ($unit)',
                value: weightDisplay,
                min: 0,
                step: step,
                decimals: 1,
                onChanged: (v) => setState(() => weightDisplay = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final weightKg = unit == 'lbs' ? lbsToKg(weightDisplay) : weightDisplay;
                onAddAbsoluteSets(sets, reps, weightKg);
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
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
              onPressed: () => _showPercentageSetDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add sets (%)'),
            ),
            TextButton.icon(
              onPressed: () => _showAbsoluteSetDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add sets (weight)'),
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

/// A labeled numeric input with tap-to-adjust [-] / [+] buttons, floored at
/// [min]; the middle field also accepts direct typed entry.
class _NumberField extends StatefulWidget {
  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.step,
    required this.decimals,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double step;
  final int decimals;
  final ValueChanged<double> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _controller = TextEditingController(text: _format(widget.value));
  final _focusNode = FocusNode();

  String _format(double v) => v.toStringAsFixed(widget.decimals);

  @override
  void initState() {
    super.initState();
    // Tabbing or clicking away doesn't fire onSubmitted (that only fires on
    // Enter/"done"), so a typed value would otherwise be silently dropped.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commitTyped();
    });
  }

  @override
  void didUpdateWidget(_NumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commitTyped() => _apply(double.tryParse(_controller.text) ?? widget.value);

  void _apply(double next) {
    final clamped = next < widget.min ? widget.min : next;
    widget.onChanged(double.parse(clamped.toStringAsFixed(widget.decimals)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(widget.label)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: widget.value - widget.step < widget.min
                ? null
                : () => _apply(widget.value - widget.step),
          ),
          SizedBox(
            width: 64,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (_) => _commitTyped(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _apply(widget.value + widget.step),
          ),
        ],
      ),
    );
  }
}
