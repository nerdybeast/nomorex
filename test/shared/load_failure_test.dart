import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/core/theme/app_theme.dart';
import 'package:nomorex/shared/widgets/load_failure.dart';

/// Fails every time it builds, counting the attempts.
class _Failing extends AsyncNotifier<List<String>> {
  static int builds = 0;
  @override
  Future<List<String>> build() async {
    builds++;
    throw Exception('PostgrestException(message: relation does not exist)');
  }
}

final _failing = AsyncNotifierProvider<_Failing, List<String>>(_Failing.new);

class _Screen extends ConsumerWidget {
  const _Screen();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_failing);
    return Scaffold(
      body: async.whenLoaded(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => LoadFailureView(
          title: "Couldn't load your workouts",
          retrying: async.retrying,
          onRetry: () => ref.invalidate(_failing),
        ),
        data: (items) => Text('${items.length} items'),
      ),
    );
  }
}

Future<void> _pump(WidgetTester tester, {Duration? Function(int, Object)? retry}) async {
  _Failing.builds = 0;
  await tester.pumpWidget(
    ProviderScope(
      retry: retry ?? (_, _) => null,
      child: MaterialApp(theme: AppTheme.dark(), home: const _Screen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('a failed load says what failed, never the raw error', (tester) async {
    await _pump(tester);

    expect(find.text("Couldn't load your workouts"), findsOneWidget);
    expect(find.text(kLoadFailureHint), findsOneWidget);
    expect(find.textContaining('PostgrestException'), findsNothing);
  });

  testWidgets('Try again loads again', (tester) async {
    await _pump(tester);
    expect(_Failing.builds, 1);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(_Failing.builds, 2);
  });

  testWidgets('while Riverpod retries, the failure shows rather than a spinner', (tester) async {
    await _pump(tester, retry: (count, _) => count < 1 ? const Duration(seconds: 5) : null);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(kLoadFailureRetrying), findsOneWidget);

    // The scheduled retry fails too; the view settles on its final message.
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(_Failing.builds, 2);
    expect(find.text(kLoadFailureRetrying), findsNothing);
    expect(find.text(kLoadFailureHint), findsOneWidget);
  });

  testWidgets('the title is a heading', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(tester.getSemantics(find.text("Couldn't load your workouts")), isSemantics(isHeader: true));
    handle.dispose();
  });

  testWidgets('a failure row fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LoadFailureRow(message: "Couldn't load workouts in progress", onRetry: () {}),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
