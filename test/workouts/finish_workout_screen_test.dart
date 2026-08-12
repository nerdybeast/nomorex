import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/features/workouts/models/workout.dart';
import 'package:nomorex/features/workouts/providers/workout_detail_provider.dart';
import 'package:nomorex/features/workouts/screens/finish_workout_screen.dart';

class _StubWorkoutDetailNotifier extends WorkoutDetailNotifier {
  _StubWorkoutDetailNotifier(this._workout, {this.onFinish, this.onDiscard});
  Workout _workout;
  final void Function(String? sessionNotes)? onFinish;
  final VoidCallback? onDiscard;

  @override
  Future<Workout> build(String workoutId) async => _workout;

  @override
  Future<void> finishWorkout({String? sessionNotes}) async {
    onFinish?.call(sessionNotes);
  }

  // Mirrors discard_workout_session's real effect (status back to
  // not_started, startedAt/pausedAt cleared) and invalidates/refetches like
  // the real notifier's _refresh() — so this stub actually exercises the
  // screen rebuilding, still mounted, with the now-null startedAt right
  // before navigation, the same way the real notifier does.
  @override
  Future<void> discardSession() async {
    onDiscard?.call();
    _workout = Workout(
      id: _workout.id,
      userId: _workout.userId,
      title: _workout.title,
      date: _workout.date,
      updatedAt: _workout.updatedAt,
      status: 'not_started',
    );
    ref.invalidateSelf();
    await future;
  }
}

Workout _pausedWorkout({String? sessionNotes}) {
  final startedAt = DateTime(2026, 8, 11, 10, 0, 0);
  return Workout(
    id: 'w1',
    userId: 'u1',
    title: 'Workout 1',
    date: DateTime(2026, 8, 11),
    updatedAt: DateTime(2026, 8, 11),
    status: 'paused',
    startedAt: startedAt,
    pausedAt: startedAt.add(const Duration(hours: 1, minutes: 2, seconds: 3)),
    sessionNotes: sessionNotes,
  );
}

// Starts on a stand-in "previous screen" (mirroring how FinishWorkoutScreen
// is always reached — pushed on top of WorkoutDetailScreen), so tests can
// push('/w1/finish') and exercise Save's context.pop() realistically.
GoRouter _router(Widget destination) => GoRouter(
      initialLocation: '/workouts/w1',
      routes: [
        GoRoute(path: '/workouts/w1', builder: (_, _) => const Text('destination:detail')),
        GoRoute(path: '/w1/finish', builder: (_, _) => destination),
        GoRoute(path: '/shell/workouts', builder: (_, _) => const Text('destination:list')),
      ],
    );

void main() {
  testWidgets('shows the frozen duration computed from pausedAt', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(() => _StubWorkoutDetailNotifier(_pausedWorkout())),
        ],
        child: const MaterialApp(home: FinishWorkoutScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('01:02:03'), findsOneWidget);
  });

  testWidgets('Save calls finishWorkout with the typed notes and pops back to the previous screen',
      (tester) async {
    String? captured;
    var called = false;
    final router = _router(const FinishWorkoutScreen(workoutId: 'w1'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(
              _pausedWorkout(),
              onFinish: (notes) {
                called = true;
                captured = notes;
              },
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/w1/finish');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Felt strong today');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(captured, 'Felt strong today');
    // Popped, not go()'d — a real back button/navigation exists on the
    // revealed screen, unlike go() which would have discarded it.
    expect(find.text('destination:detail'), findsOneWidget);
  });

  testWidgets('Discard opens a confirmation dialog; cancel leaves the session untouched',
      (tester) async {
    var called = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(_pausedWorkout(), onDiscard: () => called = true),
          ),
        ],
        child: const MaterialApp(home: FinishWorkoutScreen(workoutId: 'w1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Discard workout?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(called, isFalse);
    expect(find.byType(FinishWorkoutScreen), findsOneWidget);
  });

  testWidgets('confirming Discard calls discardSession and navigates to the workouts list',
      (tester) async {
    var called = false;
    final router = _router(const FinishWorkoutScreen(workoutId: 'w1'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workoutDetailProvider('w1').overrideWith(
            () => _StubWorkoutDetailNotifier(_pausedWorkout(), onDiscard: () => called = true),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.push('/w1/finish');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    // Two "Discard" buttons now exist (the page's and the dialog's, both
    // FilledButtons) — tap the one inside the confirmation dialog.
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Discard'),
    ));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(find.text('destination:list'), findsOneWidget);
  });
}
