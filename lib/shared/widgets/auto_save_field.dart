import 'package:flutter/material.dart';

// Tabbing or clicking away doesn't fire onFieldSubmitted (that only fires on
// Enter/"done"), so a typed value would otherwise be silently dropped —
// commit on blur too, same pattern as edit_workout_screen's _AutoSaveField.
/// A text field that saves on submit and on losing focus, and takes a new
/// value from [initialValue] when the saved data changes underneath it.
class AutoSaveField extends StatefulWidget {
  const AutoSaveField({
    super.key,
    required this.initialValue,
    required this.labelText,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String? initialValue;
  final String labelText;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<AutoSaveField> createState() => _AutoSaveFieldState();
}

class _AutoSaveFieldState extends State<AutoSaveField> {
  late final _controller = TextEditingController(text: widget.initialValue);
  final _focusNode = FocusNode();
  late String _lastCommitted = widget.initialValue ?? '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(AutoSaveField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue &&
        widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue ?? '';
      _lastCommitted = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _commit() {
    if (_controller.text == _lastCommitted) return;
    _lastCommitted = _controller.text;
    widget.onChanged(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: widget.maxLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: widget.labelText),
      onFieldSubmitted: (_) => _commit(),
    );
  }
}
