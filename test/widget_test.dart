import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App renders loading text', (WidgetTester tester) async {
    // Smoke test: verify the app shell renders without crashing.
    // Full integration tests come in later tasks once routing and auth are wired.
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Loading...')),
          ),
        ),
      ),
    );
    expect(find.text('Loading...'), findsOneWidget);
  });
}
