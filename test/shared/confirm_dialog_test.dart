import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/widgets/confirm_dialog.dart';

Widget _harness(void Function(bool) onResult) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final confirmed = await showConfirmDialog(
                context,
                title: 'Delete workout?',
                message: 'This permanently deletes it.',
                confirmLabel: 'Delete',
              );
              onResult(confirmed);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

void main() {
  testWidgets('renders the title and message', (tester) async {
    await tester.pumpWidget(_harness((_) {}));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete workout?'), findsOneWidget);
    expect(find.text('This permanently deletes it.'), findsOneWidget);
  });

  testWidgets('Cancel returns false', (tester) async {
    bool? result;
    await tester.pumpWidget(_harness((r) => result = r));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('tapping the confirm button returns true', (tester) async {
    bool? result;
    await tester.pumpWidget(_harness((r) => result = r));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
