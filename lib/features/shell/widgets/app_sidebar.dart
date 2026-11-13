import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_formatter.dart';
import '../../admin/providers/current_roles_provider.dart';
import '../../ai/providers/ai_import_intake_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../../programs/models/program_instance.dart';
import '../../programs/providers/program_instances_list_provider.dart';
import '../../programs/utils/program_progress.dart';
import '../../workouts/models/workout.dart';
import '../../workouts/providers/in_progress_workouts_provider.dart';
import '../../workouts/widgets/elapsed_timer.dart';
import '../nav_section.dart';

/// Everyone is on the free plan today. When paid tiers exist this comes from
/// the account, and a paid plan shows in `primaryText` instead of `info`.
const _kPlanLabel = 'Free';

/// The wide-layout navigation (600px and up): New, the five sections, what's
/// running, and the account. [collapsed] shows it as a rail of icons.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.location,
    required this.collapsed,
    required this.newMenu,
    required this.onToggle,
  });

  /// The current path, which decides the selected section and running item.
  final String location;
  final bool collapsed;
  final MenuController newMenu;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = NomorexTokens.of(context).palette;
    final section = navSectionFor(location);
    final isAdmin = ref.watch(isAdminProvider);

    return Material(
      key: const Key('app_sidebar'),
      color: palette.bg1,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(right: BorderSide(color: palette.borderSubtle))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(collapsed: collapsed, onToggle: onToggle),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 6 : 12, vertical: 12),
                children: [
                  _NewButton(controller: newMenu, collapsed: collapsed),
                  SizedBox(height: collapsed ? 12 : 16),
                  for (final tab in NavSection.tabs) ...[
                    _NavItem(
                      section: tab,
                      selected: section == tab,
                      collapsed: collapsed,
                      onTap: () => context.go(tab.route),
                    ),
                    const SizedBox(height: 2),
                  ],
                  _Running(location: location, collapsed: collapsed),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: palette.borderSubtle))),
              child: Padding(
                padding: EdgeInsets.fromLTRB(collapsed ? 8 : 12, 8, collapsed ? 8 : 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isAdmin) ...[
                      _NavItem(
                        section: NavSection.admin,
                        selected: section == NavSection.admin,
                        collapsed: collapsed,
                        onTap: () => _openOnTop(context, location, NavSection.admin.route),
                      ),
                      const SizedBox(height: 6),
                    ],
                    _AccountCard(
                      location: location,
                      collapsed: collapsed,
                      selected: section == NavSection.profile,
                      isAdmin: isAdmin,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens Profile or Admin on top of the current page, the way the phone
/// layout's app-bar buttons do, so the page keeps a back button if the window
/// narrows to phone width. Does nothing when [route] is already showing, so
/// repeated clicks don't stack copies.
void _openOnTop(BuildContext context, String location, String route) {
  if (location == route) return;
  context.push(route);
}

/// The wordmark and the collapse toggle, as tall as an app bar so its bottom
/// border lines up with the page's.
class _Header extends StatelessWidget {
  const _Header({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NomorexTokens.of(context).palette;
    final style = theme.textTheme.titleMedium?.copyWith(color: palette.fg1);
    final mark = Text.rich(
      TextSpan(children: [
        TextSpan(text: collapsed ? 'N' : 'NoMore'),
        TextSpan(text: 'X', style: TextStyle(color: palette.primaryText)),
      ]),
      style: style,
      semanticsLabel: 'NoMoreX',
    );
    final toggle = IconButton(
      key: const Key('sidebar_toggle'),
      tooltip: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
      onPressed: onToggle,
      color: palette.fg3,
      // 36px, so "NX" and the toggle fit side by side on the 76px rail.
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      // The stock icon draws its panel on the right; flipped, it sits on the
      // left where the sidebar is.
      icon: Transform.flip(flipX: true, child: const Icon(Icons.view_sidebar_outlined, size: 20)),
    );
    return Container(
      height: NomorexSizes.appBarHeight,
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.borderSubtle))),
      padding: collapsed ? EdgeInsets.zero : const EdgeInsets.only(left: 16, right: 6),
      child: Row(
        mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: collapsed ? [mark, toggle] : [Expanded(child: mark), toggle],
      ),
    );
  }
}

/// "New": a neutral button with a menu, so each page's own main action stays
/// the only orange fill. Opens to the right of the button on the rail.
class _NewButton extends ConsumerWidget {
  const _NewButton({required this.controller, required this.collapsed});

  final MenuController controller;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final importEnabled = ref.watch(aiImportLimitsProvider.select((l) => l.value?.enabled ?? false));

    final items = <Widget>[
      for (final action in kNewItemActions)
        _menuItem(context, icon: action.icon, label: action.label, route: action.route),
      if (importEnabled) ...[
        const Divider(height: 9),
        _menuItem(
          context,
          key: const Key('ai_import_entry'),
          icon: Icons.document_scanner_outlined,
          label: 'Import from photos or PDFs',
          route: AppConstants.routeAiImport,
        ),
      ],
    ];

    return MenuAnchor(
      controller: controller,
      // Below the button when expanded; level with it, to its right, on the
      // rail, so the menu doesn't cover the rail's own icons.
      alignmentOffset: collapsed ? const Offset(8, 0) : const Offset(0, 6),
      style: MenuStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        alignment: collapsed ? AlignmentDirectional.topEnd : AlignmentDirectional.bottomStart,
      ),
      menuChildren: items,
      builder: (context, controller, _) {
        void toggle() => controller.isOpen ? controller.close() : controller.open();
        final button = FilledButton(
          key: const Key('shell_add_fab'),
          style: tokens.secondaryButtonStyle.copyWith(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(NomorexSizes.controlHeightLg)),
            padding: WidgetStatePropertyAll(
              collapsed ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          onPressed: toggle,
          child: collapsed
              ? Icon(Icons.add, size: 20, color: palette.fg2, semanticLabel: 'New')
              : Row(
                  children: [
                    Icon(Icons.add, size: 20, color: palette.fg2),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('New')),
                    _KeyHint(label: 'N'),
                  ],
                ),
        );
        return collapsed ? Tooltip(message: 'New', child: button) : button;
      },
    );
  }

  Widget _menuItem(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String label,
    required String route,
  }) {
    return MenuItemButton(
      key: key,
      leadingIcon: Icon(icon, size: 20),
      style: const ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(240, NomorexSizes.controlHeightLg)),
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      ),
      onPressed: () => context.push(route),
      child: Text(label),
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.palette.borderDefault),
          borderRadius: BorderRadius.circular(NomorexSizes.radiusSm),
        ),
        child: Text(label, style: tokens.weightXs.copyWith(color: tokens.palette.fg3)),
      ),
    );
  }
}

/// One destination. Expanded: icon and label in a row. Rail: the label under
/// the icon, as on the phone's bottom bar.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final NavSection section;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NomorexTokens.of(context).palette;
    final icon = Icon(
      selected ? section.selectedIcon : section.icon,
      size: 20,
      color: selected ? palette.primaryText : palette.fg3,
    );
    final labelColor = selected ? palette.fg1 : palette.fg2;

    final content = collapsed
        ? SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                icon,
                const SizedBox(height: 4),
                // "Community" is the longest label; on the rail it shrinks a
                // touch rather than being cut short.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      section.label,
                      maxLines: 1,
                      style: theme.textTheme.labelSmall?.copyWith(color: labelColor),
                    ),
                  ),
                ),
              ],
            ),
          )
        : SizedBox(
            height: NomorexSizes.controlHeightLg,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(section.label, style: theme.textTheme.titleSmall?.copyWith(color: labelColor)),
                  ),
                ],
              ),
            ),
          );

    // Says it's a link to a place and which one is current, the way
    // NavigationRail did. The subtree's own semantics are replaced, so the
    // tap action is re-declared here.
    return Semantics(
      button: true,
      selected: selected,
      label: section.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? palette.bg3 : Colors.transparent,
        borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
          hoverColor: palette.bg3,
          focusColor: palette.bg3,
          child: content,
        ),
      ),
    );
  }
}

/// What's live right now: a session in progress, and each program run with
/// where today falls in it. One click from any screen.
class _Running extends ConsumerWidget {
  const _Running({required this.location, required this.collapsed});

  final String location;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final workoutsAsync = ref.watch(inProgressWorkoutsProvider);
    final instancesAsync = ref.watch(currentProgramInstancesProvider);
    final workouts = workoutsAsync.value ?? const <Workout>[];
    final instances = instancesAsync.value ?? const <ProgramInstance>[];
    final loaded = workoutsAsync.hasValue && instancesAsync.hasValue;

    final items = [
      for (final workout in workouts)
        _RunningItem(
          key: ValueKey('running_workout_${workout.id}'),
          title: workout.title,
          detail: workout.status == 'paused' ? 'Paused' : 'Session in progress',
          live: workout.status != 'paused',
          trailing: workout.startedAt == null
              ? null
              : ElapsedTimer(
                  startedAt: workout.startedAt!,
                  totalPausedSeconds: workout.totalPausedSeconds,
                  pausedAt: workout.pausedAt,
                  style: tokens.weightSm.copyWith(color: tokens.palette.fg1),
                ),
          railLabel: workout.status == 'paused' ? 'Paused' : 'Live',
          selected: location == AppConstants.routeWorkoutDetail(workout.id),
          collapsed: collapsed,
          onTap: () => context.push(AppConstants.routeWorkoutDetail(workout.id)),
        ),
      for (final instance in instances)
        _RunningItem(
          key: ValueKey('running_program_${instance.id}'),
          title: instance.programName ?? 'Program',
          detail: _runDetail(instance),
          today: _todayWeek(instance) != null,
          live: !isProgramUpcoming(instance.startedAt),
          railLabel: isProgramUpcoming(instance.startedAt)
              ? 'Soon'
              : _todayWeek(instance) != null
                  ? 'Today'
                  : 'Running',
          selected: location == AppConstants.routeProgramInstanceDetail(instance.id),
          collapsed: collapsed,
          onTap: () => context.push(AppConstants.routeProgramInstanceDetail(instance.id)),
        ),
    ];

    if (collapsed) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: tokens.palette.borderSubtle))),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(children: items),
          ),
        ),
      );
    }

    // Nothing until both lists load, so the empty line never flashes up
    // before a running session appears.
    if (!loaded && items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Text('RUNNING', style: tokens.eyebrow.copyWith(color: tokens.palette.fg3)),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Nothing running. Start a program or workout and it shows up here.',
                style: theme.textTheme.bodySmall?.copyWith(color: tokens.palette.fg3),
              ),
            )
          else
            ...items,
        ],
      ),
    );
  }

  /// The 1-based week holding today's scheduled day, or null when today isn't
  /// one of the run's days.
  static int? _todayWeek(ProgramInstance instance) {
    final weeks = instance.structure;
    if (weeks == null) return null;
    for (var i = 0; i < weeks.length; i++) {
      for (final day in weeks[i].days) {
        if (isProgramDayToday(instance.startedAt, day.position)) return i + 1;
      }
    }
    return null;
  }

  static bool _todayIsRest(ProgramInstance instance) {
    for (final week in instance.structure ?? const []) {
      for (final day in week.days) {
        if (isProgramDayToday(instance.startedAt, day.position)) return day.isRest;
      }
    }
    return false;
  }

  static String _runDetail(ProgramInstance instance) {
    if (isProgramUpcoming(instance.startedAt)) return 'Starts ${formatDate(instance.startedAt)}';
    final week = _todayWeek(instance);
    if (week == null) return 'In progress';
    return _todayIsRest(instance) ? 'Week $week · rest day' : 'Week $week';
  }
}

class _RunningItem extends StatelessWidget {
  const _RunningItem({
    super.key,
    required this.title,
    required this.detail,
    required this.railLabel,
    required this.selected,
    required this.collapsed,
    required this.onTap,
    this.live = true,
    this.today = false,
    this.trailing,
  });

  final String title;
  final String detail;
  final String railLabel;
  final bool selected;
  final bool collapsed;
  final VoidCallback onTap;

  /// Orange dot with a halo while it's happening; a gray dot when paused or
  /// not started yet.
  final bool live;

  /// Leads the detail with an orange "Today".
  final bool today;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = NomorexTokens.of(context).palette;
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: live ? palette.primary : palette.fg3,
        shape: BoxShape.circle,
        boxShadow: live ? [BoxShadow(color: palette.primarySubtle, spreadRadius: 3)] : null,
      ),
    );

    final Widget content;
    if (collapsed) {
      content = SizedBox(
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            dot,
            const SizedBox(height: 6),
            Text(railLabel, style: theme.textTheme.labelSmall?.copyWith(color: palette.fg2)),
          ],
        ),
      );
    } else {
      final detailStyle = theme.textTheme.bodySmall?.copyWith(color: palette.fg2);
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 6), child: dot),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NomorexTokens.of(context).buttonSmall.copyWith(color: palette.fg1),
                  ),
                  Text.rich(
                    TextSpan(children: [
                      if (today) ...[
                        TextSpan(
                          text: 'Today',
                          style: TextStyle(color: palette.primaryText, fontWeight: FontWeight.w500),
                        ),
                        const TextSpan(text: ' · '),
                      ],
                      TextSpan(text: detail),
                    ]),
                    style: detailStyle,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      );
    }

    final semanticsLabel = '$title, ${today ? 'today, ' : ''}$detail';
    final tile = Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: selected ? palette.bg3 : Colors.transparent,
        borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
          hoverColor: palette.bg3,
          focusColor: palette.bg3,
          child: content,
        ),
      ),
    );
    return collapsed ? Tooltip(message: '$title · ${today ? 'Today · ' : ''}$detail', child: tile) : tile;
  }
}

/// Who's signed in, their role and their plan; opens Profile. On the rail,
/// just the avatar.
class _AccountCard extends ConsumerWidget {
  const _AccountCard({
    required this.location,
    required this.collapsed,
    required this.selected,
    required this.isAdmin,
  });

  final String location;

  final bool collapsed;
  final bool selected;
  final bool isAdmin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final displayName = ref.watch(displayNameProvider);
    final email = ref.watch(currentAuthUserProvider)?.email;
    final name = (displayName?.trim().isNotEmpty ?? false) ? displayName!.trim() : (email ?? 'Profile');
    void open() => _openOnTop(context, location, AppConstants.routeProfile);

    final avatar = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.bg2,
        shape: BoxShape.circle,
        border: Border.all(color: palette.borderDefault),
      ),
      child: Text(
        name.characters.first.toUpperCase(),
        style: theme.textTheme.titleSmall?.copyWith(color: palette.fg1, fontWeight: FontWeight.w600),
      ),
    );

    final radius = BorderRadius.circular(collapsed ? NomorexSizes.radiusMd : NomorexSizes.radiusLg);
    final Widget content = collapsed
        ? SizedBox(height: 52, child: Center(child: avatar))
        : Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(color: palette.fg1),
                      ),
                      const SizedBox(height: 2),
                      // Wraps rather than overflowing at large text sizes.
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (isAdmin) const _RolePill(label: 'ADMIN'),
                          Text(_kPlanLabel, style: theme.textTheme.labelMedium?.copyWith(color: palette.info)),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 20, color: palette.fg3),
              ],
            ),
          );

    final card = Semantics(
      button: true,
      selected: selected,
      label: 'Profile, $name, ${isAdmin ? 'admin, ' : ''}$_kPlanLabel plan',
      onTap: open,
      excludeSemantics: true,
      child: Material(
        key: const Key('sidebar_account'),
        color: selected ? palette.bg3 : (collapsed ? Colors.transparent : palette.bg0),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: collapsed ? BorderSide.none : BorderSide(color: selected ? palette.borderDefault : palette.borderSubtle),
        ),
        child: InkWell(
          onTap: open,
          borderRadius: radius,
          hoverColor: palette.bg3,
          focusColor: palette.bg3,
          child: content,
        ),
      ),
    );
    return collapsed ? Tooltip(message: 'Profile', child: card) : card;
  }
}

/// The mono caps role marker, drawn like `ArchivedPill`.
class _RolePill extends StatelessWidget {
  const _RolePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    return Container(
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: tokens.palette.borderDefault),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Text(label, style: tokens.eyebrow.copyWith(height: 1, color: tokens.palette.fg2))],
      ),
    );
  }
}
