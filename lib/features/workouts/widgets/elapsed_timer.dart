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
  });

  final DateTime startedAt;
  final int totalPausedSeconds;
  final DateTime? pausedAt;
  final DateTime? finishedAt;
  final Stream<void>? ticks;
  final TextStyle? style;

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
    return Text(
      formatDuration(elapsed),
      // Deliberately not Theme.of(context).textTheme.displaySmall: that
      // style uses the app's custom Google Font (Barlow), whose glyph
      // metrics overshoot its calculated line box at this weight/size,
      // visually overlapping whatever renders right after it. An explicit
      // style with a generous height avoids that.
      style: widget.style ??
          const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, height: 1.4),
    );
  }
}
