import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:nomorex/features/analytics/analytics.dart';
import 'package:nomorex/features/analytics/providers/analytics_provider.dart';
import 'package:nomorex/features/analytics/utils/screen_tracking.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingAnalytics implements AppAnalytics {
  final screens = <String>[];
  final collection = <bool>[];

  @override
  void logEvent(String name, [Map<String, Object>? params]) {}

  @override
  void logLogin() {}

  @override
  void logScreenView(String screenName) => screens.add(screenName);

  @override
  Future<void> setCollectionEnabled(bool enabled) async => collection.add(enabled);
}

void main() {
  test('Firebase is not used when it was never initialized, as in widget tests', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(analyticsProvider), isA<NoopAnalytics>());
  });

  testWidgets('screen views are named by route pattern, once per change', (tester) async {
    final analytics = _RecordingAnalytics();
    final router = GoRouter(
      initialLocation: '/workouts',
      routes: [
        GoRoute(
          path: '/workouts',
          builder: (_, _) => const Text('list'),
          routes: [GoRoute(path: ':id', builder: (_, _) => const Text('detail'))],
        ),
      ],
    );
    addTearDown(router.dispose);
    final stop = trackScreenViews(router, analytics);
    addTearDown(stop);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/workouts/3f2a-private-id');
    await tester.pumpAndSettle();
    router.go('/workouts/another-id');
    await tester.pumpAndSettle();

    // Same screen with a different record is not a new screen view, and the
    // record's ID never appears.
    expect(analytics.screens, ['/workouts', '/workouts/:id']);
  });

  group('AnalyticsConsentNotifier', () {
    Future<(ProviderContainer, _RecordingAnalytics)> load(Map<String, Object> saved) async {
      SharedPreferences.setMockInitialValues(saved);
      final analytics = _RecordingAnalytics();
      final container = ProviderContainer(overrides: [analyticsProvider.overrideWithValue(analytics)]);
      addTearDown(container.dispose);
      container.read(analyticsConsentProvider);
      await pumpEventQueue();
      return (container, analytics);
    }

    test('is on by default', () async {
      final (container, _) = await load({});
      expect(container.read(analyticsConsentProvider), isTrue);
    });

    test('loads and applies a saved opt-out', () async {
      final (container, analytics) = await load({'analytics_enabled': false});
      expect(container.read(analyticsConsentProvider), isFalse);
      expect(analytics.collection, [false]);
    });

    test('saves a change', () async {
      final (container, _) = await load({});
      await container.read(analyticsConsentProvider.notifier).setEnabled(false);
      expect(container.read(analyticsConsentProvider), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('analytics_enabled'), isFalse);
    });

    test('never turns collection on in a debug build', () async {
      final (container, analytics) = await load({});
      await container.read(analyticsConsentProvider.notifier).setEnabled(true);
      expect(analyticsCollectsInThisBuild, isFalse);
      expect(analytics.collection, everyElement(isFalse));
    });
  });
}
