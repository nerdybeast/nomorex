import 'package:flutter/widgets.dart';

/// Dismisses the on-screen keyboard when the user taps empty space.
///
/// Flutter deliberately doesn't drop text-field focus on a touch outside the
/// field on iOS/Android, so without this the keyboard stays up and covers the
/// bottom navigation until the user finds the keyboard's own "done" key.
///
/// This uses a tap recognizer rather than a raw pointer-down listener on
/// purpose: a recognizer at the root loses the gesture arena to any deeper
/// tappable (buttons, list tiles, other text fields, the exercise picker's
/// "Add custom exercise" tile) and to scroll drags, so only a tap nothing else
/// claimed reaches [_dismiss]. Unfocusing on pointer-down instead would tear
/// down an Autocomplete overlay before its option's tap could land.
///
/// `excludeFromSemantics` keeps this out of [HapticTapScope]'s hit-test, which
/// treats any semantics `onTap` in the hit path as "tappable" and would
/// otherwise buzz on every tap of dead space.
class KeyboardDismissScope extends StatelessWidget {
  const KeyboardDismissScope({super.key, required this.child});

  final Widget child;

  static void _dismiss() {
    final focus = FocusManager.instance.primaryFocus;
    // Only drop focus that belongs to a text field, so this never disturbs
    // focus traversal elsewhere (desktop/web keyboard navigation).
    if (focus?.context?.findAncestorStateOfType<EditableTextState>() != null) {
      focus!.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: _dismiss,
      child: child,
    );
  }
}
