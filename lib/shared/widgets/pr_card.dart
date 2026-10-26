import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'list_group.dart';

/// Displays a single personal best entry.
/// [exerciseName], [weightDisplay] (pre-formatted, e.g. "120.0 kg"),
/// [reps], and [dateDisplay] (pre-formatted) are all passed in as strings
/// so this widget has no dependency on the data layer.
///
/// [notes] renders full-width beneath the main row when non-empty.
/// [notesMaxLines] clips it with an ellipsis (list views want 2 so rows stay
/// scannable); leave it null to show the whole note.
///
/// [estimatedOneRepMaxDisplay] (pre-formatted, e.g. "Est. 1RM 112.5 kg") is
/// the 1RM inferred from a multi-rep entry. Pass null on singles, where the
/// estimate is just the lifted weight again.
class PrCard extends StatelessWidget {
  const PrCard({
    super.key,
    required this.exerciseName,
    required this.weightDisplay,
    required this.reps,
    required this.dateDisplay,
    this.notes,
    this.notesMaxLines,
    this.estimatedOneRepMaxDisplay,
    this.onTap,
    this.onDelete,
  });

  final String exerciseName;
  final String weightDisplay;
  final int reps;
  final String dateDisplay;
  final String? notes;
  final int? notesMaxLines;
  final String? estimatedOneRepMaxDisplay;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = NomorexTokens.of(context);
    final palette = tokens.palette;
    final note = notes;
    final estimate = estimatedOneRepMaxDisplay;
    return GroupableTile(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exerciseName, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      dateDisplay,
                      style: theme.textTheme.bodySmall?.copyWith(color: palette.fg3),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Weights are always mono, so loads line up down a list.
                  Text(weightDisplay, style: tokens.weightMd.copyWith(color: palette.fg1)),
                  Text(
                    reps == 1 ? '1 rep' : '$reps reps',
                    style: theme.textTheme.bodySmall?.copyWith(color: palette.fg3),
                  ),
                ],
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  tooltip: 'Delete',
                  onPressed: onDelete,
                ),
              ] else if (onTap != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, size: 20, color: palette.fg3),
              ],
            ],
          ),
          // Right-aligned so it reads as part of the numbers column, but
          // laid out full-width rather than as a third line inside it —
          // the 'both' unit preference makes this string long enough
          // ("Est. 1RM 394 lbs / 179 kg") to overflow a narrow column.
          if (estimate != null) ...[
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                estimate,
                style: tokens.weight.copyWith(fontSize: 12, height: 16 / 12, color: palette.info),
              ),
            ),
          ],
          // Full-width rather than tucked into the left column, so a long
          // note wraps across the whole row and the weight/reps column
          // stays lined up with the exercise name.
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              note,
              maxLines: notesMaxLines,
              overflow: notesMaxLines == null ? null : TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 13, height: 18 / 13, color: palette.fg2),
            ),
          ],
        ],
      ),
    );
  }
}
