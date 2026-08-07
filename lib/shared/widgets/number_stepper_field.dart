import 'package:flutter/material.dart';

/// A labeled numeric input with tap-to-adjust [-] / [+] buttons, floored at
/// [min]; the middle field also accepts direct typed entry.
///
/// Style params default to `null`, which falls back to ambient theme
/// defaults — existing callers get no visual change unless they opt in.
class NumberStepperField extends StatefulWidget {
  const NumberStepperField({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.step,
    required this.decimals,
    required this.onChanged,
    this.decrementButtonStyle,
    this.incrementButtonStyle,
    this.valueTextStyle,
    this.valueDecoration,
  });

  final String label;
  final double value;
  final double min;
  final double step;
  final int decimals;
  final ValueChanged<double> onChanged;
  final ButtonStyle? decrementButtonStyle;
  final ButtonStyle? incrementButtonStyle;
  final TextStyle? valueTextStyle;
  final InputDecoration? valueDecoration;

  @override
  State<NumberStepperField> createState() => _NumberStepperFieldState();
}

class _NumberStepperFieldState extends State<NumberStepperField> {
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
  void didUpdateWidget(NumberStepperField oldWidget) {
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
            style: widget.decrementButtonStyle,
            onPressed: widget.value - widget.step < widget.min
                ? null
                : () => _apply(widget.value - widget.step),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textAlign: TextAlign.center,
              style: widget.valueTextStyle,
              decoration: widget.valueDecoration ?? const InputDecoration(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onSubmitted: (_) => _commitTyped(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            style: widget.incrementButtonStyle,
            onPressed: () => _apply(widget.value + widget.step),
          ),
        ],
      ),
    );
  }
}
