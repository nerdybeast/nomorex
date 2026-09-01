import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/workout_timer.dart';
import '../../../core/utils/duration_formatter.dart';

/// Displays elapsed workout time as HH:MM:SS. Ticks once a second while
/// running (i.e. [pausedAt] and [finishedAt] are both null); otherwise
/// renders a static, frozen value. [ticks] is injectable so widget tests can
/// drive updates deterministically instead of depending on a real
/// `Timer.periodic` (a `pumpAndSettle()` flakiness trap) — it defaults to a
/// one-second periodic stream.
class ElapsedTimer extends StatefulWidget {
  const ElapsedTimer({
    super.key,
    required this.startedAt,
    required this.totalPausedSeconds,
    this.pausedAt,
    this.finishedAt,
    this.ticks,
    this.style,
    this.maxScaledWidth,
  });

  final DateTime startedAt;
  final int totalPausedSeconds;
  final DateTime? pausedAt;
  final DateTime? finishedAt;
  final Stream<void>? ticks;
  final TextStyle? style;

  /// When set, the timer scales up to fill the available width, capped at this
  /// many logical pixels, instead of rendering at a fixed font size. Left null
  /// for the compact readouts (dashboard card, finished-workout duration).
  final double? maxScaledWidth;

  bool get _isRunning => pausedAt == null && finishedAt == null;

  @override
  State<ElapsedTimer> createState() => _ElapsedTimerState();
}

class _ElapsedTimerState extends State<ElapsedTimer> {
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _syncSubscription();
  }

  @override
  void didUpdateWidget(covariant ElapsedTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._isRunning != widget._isRunning || oldWidget.ticks != widget.ticks) {
      _subscription?.cancel();
      _subscription = null;
      _syncSubscription();
    }
  }

  void _syncSubscription() {
    if (!widget._isRunning) return;
    final stream = widget.ticks ?? Stream<void>.periodic(const Duration(seconds: 1));
    _subscription = stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = computeElapsed(
      startedAt: widget.startedAt,
      totalPausedSeconds: widget.totalPausedSeconds,
      pausedAt: widget.pausedAt,
      finishedAt: widget.finishedAt,
    );
    final text = Text(
      formatDuration(elapsed),
      // Deliberately not Theme.of(context).textTheme.displaySmall: that
      // style uses the app's custom Google Font (Barlow), whose glyph
      // metrics overshoot its calculated line box at this weight/size,
      // visually overlapping whatever renders right after it. An explicit
      // style with a generous height avoids that.
      //
      // tabularFigures is load-bearing when scaling (see below): with
      // proportional digits the string's width changes as 1s and 2s swap in,
      // which would make the FittedBox re-scale — and the whole timer visibly
      // jump — every second.
      style: widget.style ??
          const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            height: 1.4,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
    );

    final maxScaledWidth = widget.maxScaledWidth;
    if (maxScaledWidth == null) return text;

    // Scale the timer to fill the content width, capped so it stops growing on
    // tablet/desktop. Every layer here is load-bearing: the Align absorbs the
    // tight cross-axis width a ListView hands its children (a bare
    // ConstrainedBox would size itself to the cap and violate that constraint)
    // and passes loose constraints down; ConstrainedBox + an infinite-width
    // SizedBox turn those back into a *tight* min(available, cap), which is
    // what FittedBox needs — under loose constraints it just sizes to the
    // child and nothing scales.
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxScaledWidth),
        child: SizedBox(
          width: double.infinity,
          child: FittedBox(fit: BoxFit.contain, child: text),
        ),
      ),
    );
  }
}
