import 'package:flutter/material.dart';
import '../../core/theme/dark_theme.dart';

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
    final note = notes;
    final estimate = estimatedOneRepMaxDisplay;
    final accent = theme.extension<NomorexDarkTokens>()?.secondaryAccent;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exerciseName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(
                          dateDisplay,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(weightDisplay, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        reps == 1 ? '1 rep' : '$reps reps',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (onDelete != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      onPressed: onDelete,
                    ),
                  ] else if (onTap != null) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ],
              ),
              // Right-aligned so it reads as part of the numbers column, but
              // laid out full-width rather than as a third line inside it —
              // the 'both' unit preference makes this string long enough
              // ("Est. 1RM 394 lbs / 179 kg") to overflow a narrow column.
              if (estimate != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    estimate,
                    style: theme.textTheme.bodySmall?.copyWith(color: accent),
                  ),
                ),
              ],
              // Full-width rather than tucked into the left column, so a long
              // note wraps across the whole card and the weight/reps column
              // stays lined up with the exercise name.
              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  note,
                  maxLines: notesMaxLines,
                  overflow: notesMaxLines == null ? null : TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
