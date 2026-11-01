import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../core/utils/app_haptics.dart';

/// Fires a haptic tick when a tap on something tappable is confirmed.
///
/// Flutter has no global haptics switch: `enableFeedback` only calls
/// `Feedback.forTap`, which is a sound on Android and nothing on iOS. Instead of
/// wrapping every button, this hit-tests each pointer-down and remembers the
/// pointer when the hit path contains a render object that exposes a tap
/// handler: either a [RenderSemanticsGestureHandler] (`GestureDetector`) or a
/// semantics annotation with `onTap` (what `InkWell` and the Material buttons
/// build). Disabled controls have a null `onTap`, and dead space has no such
/// target, so they stay silent. Text fields expose a semantic `onTap` (to take
/// focus), so any hit path through a [RenderEditable] is skipped.
///
/// The buzz is deferred to pointer-up: a touch that lands on a card and then
/// scrolls moves past [kTouchSlop] (or is cancelled by the scrollable), which
/// drops the pending tick. A second finger also drops it.
class HapticTapScope extends StatefulWidget {
  const HapticTapScope({
    super.key,
    required this.child,
    this.onTap = AppHaptics.tap,
  });

  final Widget child;

  /// Overridable so tests can observe firing without a platform channel.
  final VoidCallback onTap;

  @override
  State<HapticTapScope> createState() => _HapticTapScopeState();
}

class _HapticTapScopeState extends State<HapticTapScope> {
  /// The pointer that may still turn out to be a tap, and where it landed.
  int? _candidate;
  Offset _origin = Offset.zero;

  void _onPointerDown(PointerDownEvent event) {
    // A second finger means pinch/multi-touch, never a tap.
    if (_candidate != null) {
      _candidate = null;
      return;
    }
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    var tappable = false;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderEditable) return;
      tappable = tappable || _hasTapHandler(target);
    }
    if (!tappable) return;
    _candidate = event.pointer;
    _origin = event.position;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _candidate) return;
    if ((event.position - _origin).distance > kTouchSlop) _candidate = null;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _candidate) return;
    _candidate = null;
    widget.onTap();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _candidate) _candidate = null;
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
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
    );
  }
}
