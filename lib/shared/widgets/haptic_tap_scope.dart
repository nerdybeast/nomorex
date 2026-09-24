import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../core/utils/app_haptics.dart';

/// Fires a haptic tick whenever a pointer goes down on something tappable.
///
/// Flutter has no global haptics switch: `enableFeedback` only calls
/// `Feedback.forTap`, which is a sound on Android and nothing on iOS. Instead of
/// wrapping every button, this hit-tests each pointer-down and buzzes only when
/// the hit path contains a render object that exposes a tap handler: either a
/// [RenderSemanticsGestureHandler] (`GestureDetector`) or a semantics annotation
/// with `onTap` (what `InkWell` and the Material buttons build). Disabled
/// controls have a null `onTap`, and scrolling / dead space have no such target,
/// so they stay silent. Text fields expose a semantic `onTap` (to take focus), so
/// any hit path through a [RenderEditable] is skipped.
class HapticTapScope extends StatelessWidget {
  const HapticTapScope({
    super.key,
    required this.child,
    this.onTap = AppHaptics.tap,
  });

  final Widget child;

  /// Overridable so tests can observe firing without a platform channel.
  final VoidCallback onTap;

  void _onPointerDown(PointerDownEvent event) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    var tappable = false;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderEditable) return;
      tappable = tappable || _hasTapHandler(target);
    }
    if (tappable) onTap();
  }

  static bool _hasTapHandler(HitTestTarget target) => switch (target) {
    RenderSemanticsGestureHandler(:final onTap) => onTap != null,
    SemanticsAnnotationsMixin(:final properties) => properties.onTap != null,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      child: child,
    );
  }
}
