import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/list_group.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../../shared/widgets/start_option_tile.dart';
import '../../ai/providers/ai_import_intake_provider.dart';
import '../../shell/nav_section.dart';

/// Home for an account with nothing on the dashboard yet: one main action and
/// the other ways in, instead of a column of empty sections.
///
/// The main action is importing a program, the fastest way to something
/// runnable for an athlete who already has one on paper. While imports are
/// switched off (`ai_import_limits.enabled`) it falls back to Community, so
/// the page always has exactly one orange fill.
class GettingStarted extends ConsumerWidget {
  const GettingStarted({super.key, required this.hasPrograms});

  /// The user already owns programs, so "build one" becomes "start one".
  final bool hasPrograms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limits = ref.watch(aiImportLimitsProvider);
    // Wait for the switch rather than flashing the fallback first. A failed
    // read counts as off, the same as the New menu.
    if (limits.isLoading && !limits.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final importEnabled = limits.value?.enabled ?? false;

    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);

    final community = StartOptionTile(
      key: const Key('get_started_community'),
      icon: NavSection.community.icon,
      title: 'Find a program in Community',
      detail: 'Save your own copy of a program someone shared.',
      onTap: () => context.go(AppConstants.routeCommunity),
    );

    final primary = importEnabled
        ? (
            label: 'Import a program',
            icon: kAiImportAction.icon,
            note: "From a PDF or photos of your coach's sheet.",
            onPressed: () => context.push(kAiImportAction.route),
          )
        : (
            label: 'Find a program in Community',
            icon: NavSection.community.icon,
            note: 'Save your own copy of a program someone shared.',
            onPressed: () => context.go(AppConstants.routeCommunity),
          );

    final mobile = isMobile(context);
    final button = FilledButton.icon(
      key: const Key('get_started_primary'),
      // The theme stretches filled buttons to full width; beside the sidebar
      // it takes its own width instead, as a button stretched across 840px
      // reads as a banner.
      style: mobile ? null : const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, 44))),
      onPressed: primary.onPressed,
      icon: Icon(primary.icon, size: 18),
      label: Text(primary.label),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Welcome to NoMoreX', style: theme.textTheme.headlineMedium),
        ),
        const SizedBox(height: 8),
        Text(
          importEnabled
              ? "Bring in the program you're following and log it set by set."
              : 'Find a program to follow or build your own, then log it set by set.',
          style: theme.textTheme.bodyMedium?.copyWith(color: tokens.palette.fg2),
        ),
        const SizedBox(height: 20),
        if (mobile) button else Row(children: [button]),
        const SizedBox(height: 8),
        Text(primary.note, style: theme.textTheme.bodySmall?.copyWith(color: tokens.fg3)),
        const SizedBox(height: 32),
        ListGroup(
          children: [
            if (importEnabled) community,
            hasPrograms
                ? StartOptionTile(
                    key: const Key('get_started_programs'),
                    icon: Icons.checklist_outlined,
                    title: 'Start one of your programs',
                    detail: 'Choose a start date and each training day becomes a workout.',
                    onTap: () => context.go(AppConstants.routePrograms),
                  )
                : StartOptionTile(
                    key: const Key('get_started_build'),
                    icon: Icons.checklist_outlined,
                    title: 'Build your own program',
                    detail: 'Lay out the weeks, days and sets yourself.',
                    onTap: () => context.push(AppConstants.routeProgramNew),
                  ),
            StartOptionTile(
              key: const Key('get_started_maxes'),
              icon: Icons.emoji_events_outlined,
              title: 'Enter your maxes',
              detail: 'Your PRs turn every %1RM set into a weight on the bar.',
              onTap: () => context.push(AppConstants.routeAddPr),
            ),
          ],
        ),
      ],
    );
  }
}
