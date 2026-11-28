import 'package:material_ui/material_ui.dart';

// Tabbing or clicking away doesn't fire onFieldSubmitted (that only fires on
// Enter/"done"), so a typed value would otherwise be silently dropped —
// commit on blur too, same pattern as edit_workout_screen's _AutoSaveField.
/// A text field that saves on submit and on losing focus, and takes a new
/// value from [initialValue] when the saved data changes underneath it.
/// See [AutoSaveField.suffixBuilder].
typedef AutoSaveFieldSuffixBuilder =
    Widget? Function(BuildContext context, String Function() currentText, ValueChanged<String> replace);

class AutoSaveField extends StatefulWidget {
  const AutoSaveField({
    super.key,
    required this.initialValue,
    required this.labelText,
    required this.onChanged,
    this.maxLines = 1,
    this.suffixBuilder,
  });

  final String? initialValue;
  final String labelText;
  final int maxLines;
  final ValueChanged<String> onChanged;

  /// Builds a button at the field's end, such as AI Suggest. It's given the
  /// field's current text and a `replace` that puts new text in and saves it,
  /// the way typing and leaving the field would.
  final AutoSaveFieldSuffixBuilder? suffixBuilder;

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

  void _replace(String text) {
    _controller.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    _commit();
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
      decoration: InputDecoration(
        labelText: widget.labelText,
        suffixIcon: widget.suffixBuilder?.call(context, () => _controller.text, _replace),
        // No reserved 48 px when the builder shows nothing (an IconButton
        // keeps its own tap target).
        suffixIconConstraints: widget.suffixBuilder == null ? null : const BoxConstraints(),
      ),
      onFieldSubmitted: (_) => _commit(),
    );
  }
}
