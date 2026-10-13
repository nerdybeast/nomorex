import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/widgets/copied_from_badge.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('shows the author for a copy', (tester) async {
    await tester.pumpWidget(_wrap(const CopiedFromBadge(
      isCopy: true,
      copiedFromUserId: 'u1',
      copiedFromDisplayName: 'BeastModeB',
      copiedFromSourceId: 'w1',
    )));
    expect(find.text('Copied from BeastModeB'), findsOneWidget);
  });

  testWidgets('renders nothing for content the user created', (tester) async {
    await tester.pumpWidget(_wrap(const CopiedFromBadge(isCopy: false)));
    expect(find.textContaining('Copied from'), findsNothing);
    expect(find.byIcon(Icons.content_copy_outlined), findsNothing);
  });
}
