import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/harness.dart';
import 'support/pages/program_sessions_page.dart';
import 'support/pages/shell_page.dart';

SupabaseClient get _db => Supabase.instance.client;

/// A program of one week (7 days, each with its one session) whose Day 1 is a
/// training day with a Back Squat. Built through the API: the editor flows
/// that build it are covered by widget tests. Named per run, so a stack this
/// suite has used before still has one program by this name.
Future<({String programId, String dayId, String sessionId, String dayTitle})> _program() async {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final program = await _db
      .from('programs')
      .insert({'user_id': _db.auth.currentUser!.id, 'name': 'E2E sessions $stamp'})
      .select('id')
      .single();
  final programId = program['id'] as String;
  final weekId = await _db.rpc('add_program_week', params: {'p_program_id': programId}) as String;
  final day = await _db
      .from('program_days')
      .select('id, program_sessions(id)')
      .eq('program_week_id', weekId)
      .eq('day_number', 1)
      .single();
  final dayId = day['id'] as String;
  final sessionId = (day['program_sessions'] as List).single['id'] as String;
  final dayTitle = 'Two-a-day $stamp';
  await _db.from('program_days').update({'title': dayTitle, 'is_rest_day': false}).eq('id', dayId);
  final squat = await _db.from('exercises').select('id').eq('name', 'Back Squat').eq('is_predefined', true).limit(1).single();
  await _db.from('program_exercises').insert({
    'program_day_id': dayId,
    'program_session_id': sessionId,
    'user_id': _db.auth.currentUser!.id,
    'exercise_id': squat['id'],
    'position': 0,
  });
  return (programId: programId, dayId: dayId, sessionId: sessionId, dayTitle: dayTitle);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a day split into two sessions runs as two workouts on the same date', (tester) async {
    await bootSignedIn(tester);
    await ShellPage(tester).waitUntilLoaded();
    final p = await _program();
    final page = ProgramSessionsPage(tester);

    await page.openDayInEditor(p.programId, weekTitle: 'Week 1', dayTitle: p.dayTitle);
    await page.addSessionTo(p.dayId, firstSessionId: p.sessionId);

    final sessions = await _db.from('program_sessions').select('id').eq('program_day_id', p.dayId).order('position');
    expect(sessions, hasLength(2));
    final secondId = sessions[1]['id'] as String;
    expect(ProgramSessionsPage.sessionMenu(secondId), findsOneWidget);

    final today = DateTime.now();
    final instanceId = await _db.rpc('start_program', params: {
      'p_program_id': p.programId,
      'p_start_date': '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
    }) as String;
    final workouts = await _db
        .from('workouts')
        .select('title, date, program_session_id')
        .eq('program_instance_id', instanceId)
        .eq('program_day_id', p.dayId);
    expect(workouts, hasLength(2));
    expect({for (final w in workouts) w['date']}, hasLength(1), reason: 'both sessions are on the day\'s date');

    await page.openRun(instanceId);
    await waitFor(tester, ProgramSessionsPage.runSessionRow(p.sessionId));
    expect(ProgramSessionsPage.runSessionRow(secondId), findsOneWidget);
    expect(ProgramSessionsPage.runRowTitled('${p.dayTitle} · Session 1'), findsOneWidget);
    expect(ProgramSessionsPage.runRowTitled('${p.dayTitle} · Session 2'), findsOneWidget);
  });
}
