import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/widgets/unit_toggle.dart';

void main() {
  testWidgets('renders a static chip with no toggle when preference is fixed to kg',
      (tester) async {
    var changed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnitToggle(
            preference: 'kg',
            value: 'kg',
            onChanged: (_) => changed = true,
          ),
        ),
      ),
    );

    expect(find.text('kg'), findsOneWidget);
    expect(find.text('lbs'), findsNothing);

    await tester.tap(find.text('kg'));
    await tester.pump();

    expect(changed, isFalse);
  });

  testWidgets('renders a static chip with no toggle when preference is fixed to lbs',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnitToggle(
            preference: 'lbs',
            value: 'lbs',
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('lbs'), findsOneWidget);
    expect(find.text('kg'), findsNothing);
  });

  testWidgets('renders an interactive pill and calls onChanged when preference is both',
      (tester) async {
    String? newUnit;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UnitToggle(
            preference: 'both',
            value: 'kg',
            onChanged: (u) => newUnit = u,
          ),
        ),
      ),
    );

    expect(find.text('kg'), findsOneWidget);
    expect(find.text('lbs'), findsOneWidget);

    await tester.tap(find.text('lbs'));
    await tester.pump();

    expect(newUnit, 'lbs');
  });

  testWidgets('each unit segment has a full touch-target tap area and button semantics',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: UnitToggle(
              preference: 'both',
              value: 'kg',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    for (final u in ['kg', 'lbs']) {
      final tapArea = find.ancestor(of: find.text(u), matching: find.byType(InkWell));
      expect(tester.getSize(tapArea).height, greaterThanOrEqualTo(48));
    }
    expect(
      tester.getSemantics(find.ancestor(of: find.text('lbs'), matching: find.byType(Semantics)).first),
      matchesSemantics(label: 'Pounds', isButton: true, hasTapAction: true, hasSelectedState: true),
    );
    handle.dispose();
  });
}
