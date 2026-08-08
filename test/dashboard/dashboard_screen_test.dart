import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nomorex/features/dashboard/screens/dashboard_screen.dart';
import 'package:nomorex/features/personal_bests/models/personal_best.dart';
import 'package:nomorex/features/personal_bests/providers/personal_bests_provider.dart';
import 'package:nomorex/features/programs/models/program_instance.dart';
import 'package:nomorex/features/programs/providers/program_instances_list_provider.dart';

class _StubPersonalBestsNotifier extends PersonalBestsNotifier {
  @override
  Future<List<PersonalBest>> build() async => [];
}

class _EmptyProgramInstancesNotifier extends CurrentProgramInstancesNotifier {
  @override
  Future<List<ProgramInstance>> build() async => [];
}

class _StubProgramInstancesNotifier extends CurrentProgramInstancesNotifier {
  _StubProgramInstancesNotifier(this._instances);
  final List<ProgramInstance> _instances;
  @override
  Future<List<ProgramInstance>> build() async => _instances;
}

void main() {
  testWidgets('shows empty state when no programs are in progress', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
          currentProgramInstancesProvider.overrideWith(() => _EmptyProgramInstancesNotifier()),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No programs currently in progress.'), findsOneWidget);
  });

  testWidgets('shows a card for an active program instance', (tester) async {
    final instance = ProgramInstance(
      id: 'pi1',
      programId: 'p1',
      programName: 'Strong Like Bull',
      userId: 'u1',
      startedAt: DateTime.now().subtract(const Duration(days: 2)),
      status: 'active',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
          currentProgramInstancesProvider
              .overrideWith(() => _StubProgramInstancesNotifier([instance])),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Strong Like Bull'), findsOneWidget);
    expect(find.textContaining('In progress'), findsOneWidget);
  });

  testWidgets('shows an upcoming program as upcoming', (tester) async {
    final instance = ProgramInstance(
      id: 'pi1',
      programId: 'p1',
      programName: 'Strong Like Bull',
      userId: 'u1',
      startedAt: DateTime.now().add(const Duration(days: 5)),
      status: 'active',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          personalBestsProvider.overrideWith(() => _StubPersonalBestsNotifier()),
          currentProgramInstancesProvider
              .overrideWith(() => _StubProgramInstancesNotifier([instance])),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Upcoming'), findsOneWidget);
  });
}
