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
    this.max,
    required this.step,
    required this.decimals,
    required this.onChanged,
    this.decrementButtonStyle,
    this.incrementButtonStyle,
    this.valueTextStyle,
    this.valueDecoration,
    this.compact = false,
  });

  final String label;
  final double value;
  final double min;
  /// Optional ceiling: + is disabled at it and typed values are clamped.
  final double? max;
  final double step;
  final int decimals;
  final ValueChanged<double> onChanged;
  final ButtonStyle? decrementButtonStyle;
  final ButtonStyle? incrementButtonStyle;
  final TextStyle? valueTextStyle;
  final InputDecoration? valueDecoration;

  /// Just the [-] value [+] cluster, sized to its content, for a row that
  /// shows its own label (the "Add sets" sheet). [label] still names the
  /// buttons for assistive tech ("Increase Reps").
  final bool compact;

  @override
  State<NumberStepperField> createState() => _NumberStepperFieldState();
}

class _NumberStepperFieldState extends State<NumberStepperField> {
  late final _controller = TextEditingController(text: _format(widget.value));
  final _focusNode = FocusNode();

  // Caps precision at widget.decimals but drops a trailing ".0"/".50" etc
  // so a whole number reads as "205", not "205.0" — the decimal only shows
  // up once the value actually has a nonzero fractional part.
  String _format(double v) {
    var text = v.toStringAsFixed(widget.decimals);
    if (!text.contains('.')) return text;
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }

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
    // A value we just reported from typing comes straight back here; leave
    // the text alone so "10." or a half-typed "1" isn't reformatted mid-edit.
    if (oldWidget.value != widget.value && widget.value != _typedValue) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// The last value reported while the user was typing, so
  /// [didUpdateWidget] can tell it apart from a change made elsewhere.
  double? _typedValue;

  double _clamp(double next) {
    final ceiling = widget.max;
    final clamped = next < widget.min
        ? widget.min
        : (ceiling != null && next > ceiling ? ceiling : next);
    return double.parse(clamped.toStringAsFixed(widget.decimals));
  }

  // Reports each keystroke that parses. The field can't rely on
  // submit/blur alone: iOS's number pad has no Done key, and tapping a
  // dialog's Save button neither submits nor unfocuses the field, so the
  // typed value would be lost (typing 100 saved 0).
  void _onTyped(String text) {
    final parsed = double.tryParse(text);
    if (parsed == null) return;
    final next = _clamp(parsed);
    _typedValue = next;
    if (next != widget.value) widget.onChanged(next);
  }

  // On submit or blur, also tidy the text to the clamped, formatted value.
  void _commitTyped() {
    final next = _clamp(double.tryParse(_controller.text) ?? widget.value);
    _typedValue = null;
    _controller.text = _format(next);
    if (next != widget.value) widget.onChanged(next);
  }

  void _apply(double next) {
    _typedValue = null;
    widget.onChanged(_clamp(next));
  }

  @override
  Widget build(BuildContext context) {
    final compact = widget.compact;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 0 : 4),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: [
          if (!compact)
            Expanded(
              child: Text(
                widget.label,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          // Named for assistive tech (and for scripts/web-shot.mjs flows,
          // which find buttons by role + name): an icon alone has no label.
          // MergeSemantics folds the label into the button's own node rather
          // than a separate unlabelled-button-in-a-labelled-group.
          MergeSemantics(
            child: Semantics(
              label: 'Decrease ${widget.label}',
              child: IconButton(
                icon: const Icon(Icons.remove, size: 20),
                style: widget.decrementButtonStyle,
                onPressed: widget.value - widget.step < widget.min
                    ? null
                    : () => _apply(widget.value - widget.step),
              ),
            ),
          ),
          SizedBox(width: compact ? 4 : 8),
          SizedBox(
            width: compact ? 52 : 80,
            child: Semantics(
              label: compact ? widget.label : null,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textAlign: TextAlign.center,
                style: widget.valueTextStyle,
                decoration: widget.valueDecoration ?? const InputDecoration(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: _onTyped,
                onSubmitted: (_) => _commitTyped(),
              ),
            ),
          ),
          SizedBox(width: compact ? 4 : 8),
          MergeSemantics(
            child: Semantics(
              label: 'Increase ${widget.label}',
              child: IconButton(
                icon: const Icon(Icons.add, size: 20),
                style: widget.incrementButtonStyle,
                onPressed: widget.max != null && widget.value + widget.step > widget.max!
                    ? null
                    : () => _apply(widget.value + widget.step),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
