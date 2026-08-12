import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/utils/workout_timer.dart';

void main() {
  final started = DateTime(2026, 8, 11, 10, 0, 0);

  test('running: elapsed counts from startedAt to now, minus paused time', () {
    final asOf = started.add(const Duration(minutes: 50));
    final elapsed = computeElapsed(
      startedAt: started,
      totalPausedSeconds: 0,
      finishedAt: asOf,
    );
    expect(elapsed, const Duration(minutes: 50));
  });

  test('paused: elapsed freezes at pausedAt, excluding time since', () {
    // Paused 10 minutes in, having accumulated no prior pause time.
    final pausedAt = started.add(const Duration(minutes: 10));
    final elapsed = computeElapsed(
      startedAt: started,
      totalPausedSeconds: 0,
      pausedAt: pausedAt,
    );
    expect(elapsed, const Duration(minutes: 10));
  });

  test('paused directly after a prior pause/resume cycle folds prior gap', () {
    // Paused at +10m for 5m (folded into total_paused_seconds by resume),
    // ran to +25m, then paused again — elapsed should reflect only active time.
    final pausedAgainAt = started.add(const Duration(minutes: 25));
    final elapsed = computeElapsed(
      startedAt: started,
      totalPausedSeconds: const Duration(minutes: 5).inSeconds,
      pausedAt: pausedAgainAt,
    );
    expect(elapsed, const Duration(minutes: 20));
  });

  test('finished: elapsed freezes at finishedAt, ignoring pausedAt', () {
    final finishedAt = started.add(const Duration(minutes: 15));
    final elapsed = computeElapsed(
      startedAt: started,
      totalPausedSeconds: const Duration(minutes: 5).inSeconds,
      finishedAt: finishedAt,
    );
    expect(elapsed, const Duration(minutes: 10));
  });

  test('clamps a negative result to zero', () {
    // finishedAt before startedAt should never happen, but must not crash
    // or return a negative Duration.
    final elapsed = computeElapsed(
      startedAt: started,
      totalPausedSeconds: 0,
      finishedAt: started.subtract(const Duration(minutes: 1)),
    );
    expect(elapsed, Duration.zero);
  });
}
