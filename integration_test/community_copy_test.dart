import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';
import 'support/pages/community_page.dart';
import 'support/pages/shell_page.dart';

// Seeded public content owned by b@b.com (supabase/seed.sql).
const _workoutTitle = 'Accessory Grinder';
const _workoutId = '6f1c8d2b-3e4a-4f5b-9c7d-8e9fa0b1c2d3';
const _programName = "B's 12-Week Volume Block";
const _customLift = 'Dude Pulls'; // b's custom exercise; a@a.com starts without it

SupabaseClient get _db => Supabase.instance.client;

Future<CommunityPage> _openCommunity(WidgetTester tester) async {
  await bootSignedIn(tester);
  final shell = ShellPage(tester);
  await shell.waitUntilLoaded();
  await shell.goToCommunity();
  return CommunityPage(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('save / start from Community', () {
    testWidgets('saving a workout makes a badged copy with the same structure', (tester) async {
      final community = await _openCommunity(tester);
      await community.openWorkout(_workoutTitle);
      await community.saveOpenWorkout();
      await community.viewSavedCopy();

      await waitFor(tester, find.byKey(const Key('copied_from_badge')));
      expect(find.text('Copied from BeastModeB'), findsOneWidget);
      // Every seeded exercise came across, in order (SC-004).
      expect(find.text(_customLift), findsOneWidget);
      expect(find.text('Front Squat'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(_customLift)).dy,
        lessThan(tester.getTopLeft(find.text('Front Squat')).dy),
      );
    });

    testWidgets('saving again never duplicates the custom lift in the viewer catalog (SC-006)',
        (tester) async {
      final community = await _openCommunity(tester);
      await community.openWorkout(_workoutTitle);
      await community.saveOpenWorkout();
      await community.saveOpenWorkout();

      // Exact count on purpose: dedupe makes this 1 however many times the
      // suite has run against this stack, so it's rerun-safe.
      final mine = await _db
          .from('exercises')
          .select('id')
          .eq('user_id', _db.auth.currentUser!.id)
          .ilike('name', _customLift);
      expect(mine, hasLength(1));

      final copies = await _db
          .from('workouts')
          .select('id')
          .eq('copied_from_workout_id', _workoutId);
      expect(copies, isNotEmpty);
    });

    testWidgets('starting a workout opens an in-progress session of a copy', (tester) async {
      final community = await _openCommunity(tester);
      await community.openWorkout(_workoutTitle);
      await community.startOpenWorkout();

      expect(find.byKey(const Key('copied_from_badge')), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('saving the 12-week program finishes within 5 seconds (SC-003)', (tester) async {
      final community = await _openCommunity(tester);
      await community.openProgram(_programName);

      final stopwatch = Stopwatch()..start();
      await community.saveOpenProgram();
      stopwatch.stop();

      // ignore: avoid_print
      print('SC-003: saving "$_programName" took ${stopwatch.elapsedMilliseconds} ms');
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });

    testWidgets('starting a program opens a badged run of a copy', (tester) async {
      final community = await _openCommunity(tester);
      await community.openProgram(_programName);
      await community.startOpenProgram();

      await waitFor(tester, find.byKey(const Key('copied_from_badge')));
      expect(find.text(_programName), findsWidgets);
      expect(find.text('Copied from BeastModeB'), findsOneWidget);
    });
  });
}
