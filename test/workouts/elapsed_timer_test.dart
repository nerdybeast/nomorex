import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/workouts/widgets/elapsed_timer.dart';

void main() {
  testWidgets('running timer advances only when a tick is received', (tester) async {
    final ticks = StreamController<void>();
    addTearDown(ticks.close);
    final startedAt = DateTime.now().subtract(const Duration(seconds: 5));

    await tester.pumpWidget(
      MaterialApp(
        home: ElapsedTimer(startedAt: startedAt, totalPausedSeconds: 0, ticks: ticks.stream),
      ),
    );

    // Real time may have advanced slightly since startedAt was computed, but
    // no tick has fired yet, so the widget shouldn't have rebuilt/advanced
    // beyond its very first computed value.
    final firstRender = tester.widget<Text>(find.byType(Text)).data;
    ticks.add(null);
    await tester.pump();
    final secondRender = tester.widget<Text>(find.byType(Text)).data;

    expect(firstRender, isNotNull);
    expect(secondRender, isNotNull);
  });

  testWidgets('paused timer renders a static value and never subscribes to ticks',
      (tester) async {
    final ticks = StreamController<void>.broadcast();
    addTearDown(ticks.close);
    final startedAt = DateTime(2026, 8, 11, 10, 0, 0);
    final pausedAt = startedAt.add(const Duration(minutes: 10));

    await tester.pumpWidget(
      MaterialApp(
        home: ElapsedTimer(
          startedAt: startedAt,
          totalPausedSeconds: 0,
          pausedAt: pausedAt,
          ticks: ticks.stream,
        ),
      ),
    );

    expect(find.text('00:10:00'), findsOneWidget);
    expect(ticks.hasListener, isFalse);

    // Pushing a tick (even though nothing should be listening) must not
    // change the static, frozen display.
    ticks.add(null);
    await tester.pump();
    expect(find.text('00:10:00'), findsOneWidget);
  });

  testWidgets('finished timer renders a static value from finishedAt', (tester) async {
    final startedAt = DateTime(2026, 8, 11, 10, 0, 0);
    final finishedAt = startedAt.add(const Duration(hours: 1, minutes: 2, seconds: 3));

    await tester.pumpWidget(
      MaterialApp(
        home: ElapsedTimer(
          startedAt: startedAt,
          totalPausedSeconds: 0,
          finishedAt: finishedAt,
        ),
      ),
    );

    expect(find.text('01:02:03'), findsOneWidget);
  });

  testWidgets('stops ticking once it transitions from running to paused', (tester) async {
    final ticks = StreamController<void>.broadcast();
    addTearDown(ticks.close);
    final startedAt = DateTime(2026, 8, 11, 10, 0, 0);

    Widget buildWidget({DateTime? pausedAt}) => MaterialApp(
          home: ElapsedTimer(
            startedAt: startedAt,
            totalPausedSeconds: 0,
            pausedAt: pausedAt,
            ticks: ticks.stream,
          ),
        );

    await tester.pumpWidget(buildWidget());
    expect(ticks.hasListener, isTrue);

    await tester.pumpWidget(buildWidget(pausedAt: startedAt.add(const Duration(minutes: 3))));
    expect(ticks.hasListener, isFalse);
    expect(find.text('00:03:00'), findsOneWidget);
  });
}
