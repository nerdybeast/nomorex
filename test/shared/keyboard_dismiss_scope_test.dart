import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/widgets/haptic_tap_scope.dart';
import 'package:nomorex/shared/widgets/keyboard_dismiss_scope.dart';

void main() {
  late FocusNode focusNode;
  late int haptics;
  late int presses;

  setUp(() {
    focusNode = FocusNode();
    haptics = 0;
    presses = 0;
  });

  tearDown(() => focusNode.dispose());

  Future<void> pump(WidgetTester tester, {bool withScope = true}) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => HapticTapScope(
          onTap: () => haptics++,
          child: withScope ? KeyboardDismissScope(child: child!) : child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              TextField(key: const Key('field'), focusNode: focusNode),
              TextButton(
                key: const Key('button'),
                onPressed: () => presses++,
                child: const Text('Press'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> focusField(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
  }

  // Bottom-right of the screen: nothing tappable there.
  Offset deadSpace(WidgetTester tester) =>
      tester.getBottomRight(find.byType(Scaffold)) - const Offset(20, 100);

  testWidgets('control: touch outside a field leaves focus without the scope',
      (tester) async {
    await pump(tester, withScope: false);
    await focusField(tester);

    await tester.tapAt(deadSpace(tester));
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('tapping empty space drops the text field focus', (tester) async {
    await pump(tester);
    await focusField(tester);

    await tester.tapAt(deadSpace(tester));
    await tester.pump();

    expect(focusNode.hasFocus, isFalse);
  });

  testWidgets('tapping a button still presses it', (tester) async {
    await pump(tester);
    await focusField(tester);

    await tester.tap(find.byKey(const Key('button')));
    await tester.pump();

    expect(presses, 1);
  });

  testWidgets('tapping into the field keeps focus on it', (tester) async {
    await pump(tester);
    await focusField(tester);

    await tester.tap(find.byKey(const Key('field')));
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
  });

  testWidgets('dead-space taps stay silent for haptics', (tester) async {
    await pump(tester);

    await tester.tapAt(deadSpace(tester));
    await tester.pump();

    expect(haptics, 0);
  });
}
