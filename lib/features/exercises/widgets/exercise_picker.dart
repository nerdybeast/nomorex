import 'package:flutter/material.dart';
import '../models/exercise.dart';

/// Autocomplete-style exercise picker with an "Add custom" fallback.
class ExercisePicker extends StatefulWidget {
  const ExercisePicker({
    super.key,
    required this.exercises,
    required this.selected,
    required this.onSelected,
    required this.onAddCustom,
    this.labelText = 'Exercise',
  });

  final List<Exercise> exercises;
  final Exercise? selected;
  final ValueChanged<Exercise> onSelected;
  final Future<void> Function(String name) onAddCustom;
  final String labelText;

  @override
  State<ExercisePicker> createState() => _ExercisePickerState();
}

// RawAutocomplete hides its options overlay entirely whenever optionsBuilder
// returns an empty iterable (see _canShowOptionsView in the framework). That
// would hide the "Add custom exercise" tile below whenever a typed name
// matches nothing, so this sentinel is appended to keep the overlay open; it
// is filtered back out before the visible list is built.
const _keepOverlayOpenSentinel = Exercise(id: '__keep_overlay_open__', name: '', isPredefined: false);

class _ExercisePickerState extends State<ExercisePicker> {
  TextEditingController? _fieldController;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Exercise>(
      displayStringForOption: (e) => e.name,
      optionsBuilder: (textEditingValue) {
        final matches = textEditingValue.text.isEmpty
            ? widget.exercises
            : widget.exercises.where(
                (e) => e.name.toLowerCase().contains(textEditingValue.text.toLowerCase()),
              );
        return [...matches, _keepOverlayOpenSentinel];
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmit) {
        _fieldController = controller;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: 'Search exercises...',
          ),
          validator: (_) => widget.selected == null ? 'Select an exercise' : null,
        );
      },
      onSelected: widget.onSelected,
      optionsViewBuilder: (context, onSelected, options) {
        final optionList = options.where((e) => e != _keepOverlayOpenSentinel).toList();
        final colorScheme = Theme.of(context).colorScheme;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: colorScheme.outline),
            ),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: optionList.length + 1,
                itemBuilder: (context, index) {
                  if (index == optionList.length) {
                    return ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Add custom exercise'),
                      onTap: () async {
                        final name = await showDialog<String>(
                          context: context,
                          builder: (ctx) {
                            final nameCtrl = TextEditingController(
                              text: _fieldController?.text ?? '',
                            );
                            return AlertDialog(
                              title: const Text('Custom Exercise'),
                              content: TextField(
                                controller: nameCtrl,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: const InputDecoration(labelText: 'Exercise name'),
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
                                  child: const Text('Add'),
                                ),
                              ],
                            );
                          },
                        );
                        if (name != null && name.isNotEmpty) {
                          await widget.onAddCustom(name);
                        }
                      },
                    );
                  }
                  final option = optionList[index];
                  return ListTile(
                    title: Text(option.name),
                    subtitle: option.isPredefined ? null : const Text('Custom'),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
