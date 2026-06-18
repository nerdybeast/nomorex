import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';
import '../../../shared/widgets/pr_card.dart';
import '../../../core/utils/weight_converter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../profile/providers/profile_provider.dart';
import '../../personal_bests/providers/personal_bests_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prs = ref.watch(dashboardPrsProvider);
    final unit = ref.watch(unitPreferenceProvider);
    final isLoading = ref.watch(personalBestsProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : prs.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No PRs yet.\nTap + to log your first personal best.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: prs.length,
                  itemBuilder: (context, index) {
                    final pr = prs[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PrCard(
                        exerciseName: pr.exerciseName,
                        weightDisplay: formatWeight(pr.weightKg, unit),
                        reps: pr.reps,
                        dateDisplay: formatDate(pr.date),
                      ),
                    );
                  },
                ),
    );
  }
}
