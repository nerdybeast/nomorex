import 'package:flutter/material.dart';

/// Displays a single personal best entry.
/// [exerciseName], [weightDisplay] (pre-formatted, e.g. "120.0 kg"),
/// [reps], and [dateDisplay] (pre-formatted) are all passed in as strings
/// so this widget has no dependency on the data layer.
class PrCard extends StatelessWidget {
  const PrCard({
    super.key,
    required this.exerciseName,
    required this.weightDisplay,
    required this.reps,
    required this.dateDisplay,
  });

  final String exerciseName;
  final String weightDisplay;
  final int reps;
  final String dateDisplay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
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
          ],
        ),
      ),
    );
  }
}
