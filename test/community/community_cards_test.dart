import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/community/widgets/community_cards.dart';
import 'package:nomorex/features/programs/models/program.dart';
import 'package:nomorex/features/programs/models/program_day.dart';
import 'package:nomorex/features/programs/models/program_week.dart';

Program _program({String? description}) => Program(
  id: 'p1',
  userId: 'u2',
  name: 'Shared Block',
  description: description,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
  weeks: [
    ProgramWeek(
      id: 'w1',
      programId: 'p1',
      weekNumber: 1,
      position: 0,
      days: [
        for (var i = 0; i < 7; i++)
          ProgramDay(id: 'd$i', programWeekId: 'w1', dayNumber: i + 1, title: 'Day', position: i, isRestDay: i >= 4),
      ],
    ),
  ],
);

Future<void> _pump(WidgetTester tester, Program program) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: CommunityProgramCard(program: program, onTap: () {}))),
);

void main() {
  testWidgets('a shared program says how many days a week it trains, not its rest days', (tester) async {
    await _pump(tester, _program());
    expect(find.text('1 week'), findsOneWidget);
    expect(find.text('4 days/wk'), findsOneWidget);
  });

  testWidgets('a shared program with no description shows no placeholder', (tester) async {
    await _pump(tester, _program());
    expect(find.text('No Description.'), findsNothing);
    await _pump(tester, _program(description: 'Four days of squats.'));
    expect(find.text('Four days of squats.'), findsOneWidget);
  });
}
