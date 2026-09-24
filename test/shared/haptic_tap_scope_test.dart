import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/shared/widgets/haptic_tap_scope.dart';

void main() {
  late int taps;

  setUp(() => taps = 0);

  Future<void> pump(WidgetTester tester, Widget body) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            HapticTapScope(onTap: () => taps++, child: child!),
        home: Scaffold(body: body),
      ),
    );
  }

  testWidgets('fires for common tappable controls', (tester) async {
    await pump(
      tester,
      Column(
        children: [
          FilledButton(
            key: const Key('filled'),
            onPressed: () {},
            child: const Text('Filled'),
          ),
          TextButton(
            key: const Key('text'),
            onPressed: () {},
            child: const Text('Text'),
          ),
          IconButton(
            key: const Key('icon'),
            onPressed: () {},
            icon: const Icon(Icons.add),
          ),
          ListTile(
            key: const Key('tile'),
            title: const Text('Tile'),
            onTap: () {},
          ),
          InkWell(
            key: const Key('ink'),
            onTap: () {},
            child: const SizedBox(width: 50, height: 50),
          ),
          Switch(key: const Key('switch'), value: false, onChanged: (_) {}),
          FloatingActionButton(
            key: const Key('fab'),
            heroTag: 'haptic_test_fab',
            onPressed: () {},
          ),
          GestureDetector(
            key: const Key('gd'),
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: const SizedBox(width: 50, height: 50),
          ),
        ],
      ),
    );

    for (final key in [
      'filled',
      'text',
      'icon',
      'tile',
      'ink',
      'switch',
      'fab',
      'gd',
    ]) {
      final before = taps;
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(taps, before + 1, reason: '$key should buzz');
    }
  });

  testWidgets(
    'stays silent for disabled controls, plain text, and dead space',
    (tester) async {
      await pump(
        tester,
        const Column(
          children: [
            FilledButton(
              key: Key('disabled'),
              onPressed: null,
              child: Text('Disabled'),
            ),
            Text('Just text', key: Key('plain')),
            TextField(key: Key('field')),
          ],
        ),
      );

      await tester.tap(find.byKey(const Key('disabled')));
      await tester.tap(find.byKey(const Key('plain')));
      await tester.tap(find.byKey(const Key('field')));
      await tester.pump();
      expect(taps, 0);
    },
  );

  testWidgets('does not fire when scrolling a list', (tester) async {
    await pump(
      tester,
      ListView(children: [for (var i = 0; i < 40; i++) Text('row $i')]),
    );
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pump();
    expect(taps, 0);
  });
}
