import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_theme.dart';
import 'list_group.dart';

/// One way in to something new (Home's getting started, the Programs list's
/// "Add a program" group): icon tile, what it is, why, and a chevron. The
/// whole row is the target, so there's no separate button inside it.
class StartOptionTile extends StatelessWidget {
  const StartOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    // One node per row: its title and detail read as one button's label.
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: GroupableTile(
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: NomorexSizes.iconTileSize,
                height: NomorexSizes.iconTileSize,
                decoration: BoxDecoration(
                  color: palette.bg2,
                  border: Border.all(color: palette.borderDefault),
                  borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
                ),
                child: ExcludeSemantics(child: Icon(icon, color: palette.fg2, size: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: palette.fg1),
                    ),
                    const SizedBox(height: 2),
                    Text(detail, style: tokens.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: tokens.fg3, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
