import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/widgets/archived_pill.dart';
import 'package:nomorex/shared/widgets/archived_row_actions.dart';
import 'package:nomorex/shared/widgets/summary_card.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('the default row shows its own icon and a chevron', (tester) async {
    await tester.pumpWidget(_wrap(
      SummaryCard(icon: Icons.fitness_center_outlined, title: 'Upper A', onTap: () {}),
    ));

    expect(find.byIcon(Icons.fitness_center_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byType(ArchivedPill), findsNothing);
  });

  testWidgets('the archived row swaps in the archive icon and the ARCHIVED pill', (tester) async {
    await tester.pumpWidget(_wrap(
      SummaryCard(
        archived: true,
        icon: Icons.fitness_center_outlined,
        title: 'Upper A',
        onTap: () {},
        trailing: ArchivedRowActions(onRestore: () {}),
      ),
    ));

    expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center_outlined), findsNothing);
    expect(find.text('ARCHIVED'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
    expect(find.text('Restore'), findsOneWidget);
  });

  testWidgets('the ARCHIVED pill hugs its label instead of filling the row', (tester) async {
    await tester.pumpWidget(_wrap(
      SummaryCard(archived: true, icon: Icons.fitness_center_outlined, title: 'A', onTap: () {}),
    ));

    expect(tester.getSize(find.byType(ArchivedPill)).width, lessThan(200));
  });

  testWidgets('ArchivedRowActions adds the delete menu only when onDelete is set', (tester) async {
    var deleted = false;
    await tester.pumpWidget(_wrap(
      ArchivedRowActions(onRestore: () {}, onDelete: () => deleted = true),
    ));

    await tester.tap(find.byKey(const Key('archived_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    expect(deleted, isTrue);

    await tester.pumpWidget(_wrap(ArchivedRowActions(onRestore: () {})));
    expect(find.byKey(const Key('archived_menu')), findsNothing);
  });
}
