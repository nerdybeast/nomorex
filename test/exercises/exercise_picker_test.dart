import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/exercises/models/exercise.dart';
import 'package:nomorex/features/exercises/widgets/exercise_picker.dart';

const _squat = Exercise(id: 'e1', name: 'Back Squat', isPredefined: true);
const _deadlift = Exercise(id: 'e2', name: 'Deadlift', isPredefined: true);

void main() {
  testWidgets('a pre-selected exercise is shown in the field on first mount',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExercisePicker(
            exercises: const [_squat, _deadlift],
            selected: _squat,
            onSelected: (_) {},
            onAddCustom: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Back Squat'), findsOneWidget);
  });

  testWidgets(
      'changing selected on a rebuild under the same key does not change the visible text',
      (tester) async {
    Widget buildPicker(Exercise? selected) => MaterialApp(
          home: Scaffold(
            body: ExercisePicker(
              exercises: const [_squat, _deadlift],
              selected: selected,
              onSelected: (_) {},
              onAddCustom: (_) async {},
            ),
          ),
        );

    await tester.pumpWidget(buildPicker(_squat));
    await tester.pumpAndSettle();
    expect(find.text('Back Squat'), findsOneWidget);

    // Same widget key (none set here, so the element is reused across this
    // rebuild) — Autocomplete only honors initialValue on its first mount,
    // so a later change to `selected` alone must not retroactively update
    // the visible field text.
    await tester.pumpWidget(buildPicker(_deadlift));
    await tester.pumpAndSettle();

    expect(find.text('Back Squat'), findsOneWidget);
    expect(find.text('Deadlift'), findsNothing);
  });

  testWidgets(
      'options list does not inherit the safe-area top inset as blank space',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 60),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: ExercisePicker(
            exercises: const [_squat, _deadlift],
            selected: null,
            onSelected: (_) {},
            onAddCustom: (_) async {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();

    final overlayTop = tester
        .getTopLeft(find.ancestor(
          of: find.text('Back Squat'),
          matching: find.byType(Material),
        ).first)
        .dy;
    final firstOptionTop = tester.getTopLeft(find.text('Back Squat')).dy;

    // A ListTile's own vertical padding is well under 30dp; the leaked
    // safe-area inset would add 60dp on top of that.
    expect(firstOptionTop - overlayTop, lessThan(30));
  });
}
