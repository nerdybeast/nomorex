import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_theme.dart';

/// A program row's lead tile: the summary card's 32px tile, carrying the
/// program's length ("6wk", in mono like every number the lifter scans)
/// instead of the same checklist glyph on every row, so near-identical names
/// ("ZT 6 Week Program", "ZT 8 Week") still read apart at a glance.
///
/// A running program adds a 2px bar along the tile's foot, filled for the
/// weeks done ([weeksDone] of [weeks]). Decorative to a screen reader: the
/// row's facts and status line say the same in words.
class ProgramWeeksTile extends StatelessWidget {
  const ProgramWeeksTile({super.key, required this.weeks, this.weeksDone});

  final int weeks;

  /// Weeks completed in a run; null for a program that isn't running.
  final int? weeksDone;

  @override
  Widget build(BuildContext context) {
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final done = weeksDone;
    return ExcludeSemantics(
      child: Container(
        width: NomorexSizes.iconTileSize,
        height: NomorexSizes.iconTileSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.bg2,
          border: Border.all(color: palette.borderDefault),
          borderRadius: BorderRadius.circular(NomorexSizes.radiusMd),
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                // Shrinks rather than clips at a large text size ("12wk").
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${weeks}wk',
                    maxLines: 1,
                    style: tokens.weightXs.copyWith(color: palette.fg2),
                  ),
                ),
              ),
            ),
            if (done != null && weeks > 0)
              // A track under the fill, so week 1 of 6 reads as a fraction
              // rather than a stray mark.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 2,
                  color: palette.borderDefault,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: (done / weeks).clamp(0, 1).toDouble(),
                    child: Container(color: palette.fg2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
