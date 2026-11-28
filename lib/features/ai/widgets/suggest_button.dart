import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/auto_save_field.dart';
import '../../programs/models/program.dart';
import '../../workouts/models/workout.dart';
import '../core/ai_provider_exception.dart';
import '../core/genkit_provider.dart';
import '../core/model_router_provider.dart';
import '../utils/suggest_text.dart';

/// The sparkle at the end of a title or description field (Stage 9, #191):
/// asks the on-device model for [field] from [outline], puts the answer in
/// the field and offers Undo. Hidden when no on-device model can run the task
/// or there's nothing to suggest from yet ([hasContent]).
///
/// Use it as an `AutoSaveField.suffixBuilder`, which supplies [currentText]
/// and [replace].
class SuggestButton extends ConsumerStatefulWidget {
  const SuggestButton({
    super.key,
    required this.field,
    required this.subject,
    required this.noun,
    required this.source,
    required this.hasContent,
    required this.outline,
    required this.currentText,
    required this.replace,
  });

  final SuggestField field;
  final SuggestSubject subject;

  /// What the field is called, lower case: "name", "title", "description".
  final String noun;

  /// What the suggestion came from, for the snackbar: "your exercises".
  final String source;
  final bool hasContent;
  final String Function() outline;
  final String Function() currentText;
  final ValueChanged<String> replace;

  @override
  ConsumerState<SuggestButton> createState() => _SuggestButtonState();
}

class _SuggestButtonState extends ConsumerState<SuggestButton> {
  var _running = false;

  Future<void> _suggest() async {
    final route = ref.read(modelForTaskProvider(widget.field.task));
    if (route == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _running = true);
    String? suggestion;
    String? failure;
    try {
      final ai = await ref.read(genkitProvider.future);
      suggestion = await suggestText(
        ai,
        route,
        field: widget.field,
        subject: widget.subject,
        outline: widget.outline(),
      );
      if (suggestion == null) failure = "Couldn't suggest a ${widget.noun} this time. Try again.";
    } on AiProviderException catch (e) {
      failure = e.message;
    }
    if (!mounted) return;
    setState(() => _running = false);
    messenger.hideCurrentSnackBar();
    if (suggestion == null) {
      messenger.showSnackBar(SnackBar(content: Text(failure!)));
      return;
    }
    final previous = widget.currentText();
    widget.replace(suggestion);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${_capitalized(widget.noun)} suggested from ${widget.source}'),
        // With an action a snackbar otherwise stays until dismissed.
        persist: false,
        action: SnackBarAction(label: 'Undo', onPressed: () => widget.replace(previous)),
      ),
    );
  }

  static String _capitalized(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(modelForTaskProvider(widget.field.task));
    if (route == null || !widget.hasContent) return const SizedBox.shrink();
    final label = 'Suggest a ${widget.noun}';
    return IconButton(
      key: Key('suggest_${widget.field.key}'),
      tooltip: label,
      onPressed: _running ? null : _suggest,
      icon: _running
          ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.auto_awesome_outlined),
    );
  }
}

/// An `AutoSaveField.suffixBuilder` suggesting [field] for [workout].
AutoSaveFieldSuffixBuilder workoutSuggestSuffix(SuggestField field, Workout workout, String unit, {required String noun}) =>
    (context, currentText, replace) => SuggestButton(
      field: field,
      subject: SuggestSubject.workout,
      noun: noun,
      source: 'your exercises',
      hasContent: workoutHasOutline(workout),
      outline: () => workoutOutline(workout, unit),
      currentText: currentText,
      replace: replace,
    );

/// An `AutoSaveField.suffixBuilder` suggesting [field] for [program].
AutoSaveFieldSuffixBuilder programSuggestSuffix(SuggestField field, Program program, String unit, {required String noun}) =>
    (context, currentText, replace) => SuggestButton(
      field: field,
      subject: SuggestSubject.program,
      noun: noun,
      source: 'your weeks',
      hasContent: programHasOutline(program),
      outline: () => programOutline(program, unit),
      currentText: currentText,
      replace: replace,
    );
