import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/widgets/info_panel.dart';

void main() {
  Future<void> pumpPanel(WidgetTester tester) => tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: InfoPanel(
                title: 'HEADS UP',
                children: [Text('First paragraph'), Text('Second paragraph')],
              ),
            ),
          ),
        ),
      );

  testWidgets('renders the title, the info icon and every child',
      (tester) async {
    await pumpPanel(tester);

    expect(find.text('HEADS UP'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.text('First paragraph'), findsOneWidget);
    expect(find.text('Second paragraph'), findsOneWidget);
  });

  testWidgets('puts the title upper-left and the icon upper-right',
      (tester) async {
    await pumpPanel(tester);

    final panel = tester.getRect(find.byType(InfoPanel));
    final title = tester.getRect(find.text('HEADS UP'));
    final icon = tester.getRect(find.byIcon(Icons.info_outline));
    final body = tester.getRect(find.text('First paragraph'));

    expect(title.left, lessThan(panel.center.dx));
    expect(icon.right, greaterThan(panel.center.dx));
    expect(icon.center.dy, closeTo(title.center.dy, 4));
    expect(body.top, greaterThan(icon.bottom));
  });
}
