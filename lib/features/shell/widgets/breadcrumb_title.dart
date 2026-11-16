import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../nav_section.dart';

/// An app-bar title for a page inside a section ("Programs › ZT 6 Week
/// Program"). Beside the sidebar it leads with the section, or inside Training
/// with the Training view, which goes back to that list, and names the page by [current] (its own name, once
/// loaded). On a phone, where there's no sidebar to say where you are, it's
/// just [title], as before.
///
/// The back arrow stays either way: it returns to wherever the page was opened
/// from, which isn't always the section's list.
class BreadcrumbTitle extends StatelessWidget {
  const BreadcrumbTitle({super.key, required this.title, this.current});

  /// The phone title, and the wide one until [current] is known.
  final String title;

  /// This page's own name, such as the program's.
  final String? current;

  @override
  Widget build(BuildContext context) {
    final here = Text(current ?? title, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (isMobile(context) || !SidebarInset.isPresent(context)) return Text(title, overflow: TextOverflow.ellipsis);

    final path = GoRouterState.of(context).uri.path;
    final section = navSectionFor(path);
    if (section == null) return here;
    // Inside Training, lead with the view ("Programs"), which says exactly
    // where the crumb goes back to.
    final view = section == NavSection.training ? trainingViewFor(path) : null;
    final (label, route) = view != null ? (view.label, view.route) : (section.label, section.route);

    final palette = NomorexTokens.of(context).palette;
    return Row(
      children: [
        TextButton(
          key: const Key('breadcrumb_section'),
          style: TextButton.styleFrom(
            foregroundColor: palette.fg2,
            minimumSize: const Size(0, NomorexSizes.controlHeight),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            textStyle: Theme.of(context).appBarTheme.titleTextStyle,
          ),
          onPressed: () => context.go(route),
          child: Text(label),
        ),
        Icon(Icons.chevron_right, size: 18, color: palette.fg3),
        const SizedBox(width: 4),
        Flexible(child: here),
      ],
    );
  }
}
