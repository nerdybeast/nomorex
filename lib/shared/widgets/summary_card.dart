import 'package:flutter/material.dart';

/// Shared chrome for a list entry that summarizes a program or workout: an
/// icon badge, a bold [title], an optional muted [subtitle] (e.g. the author),
/// an optional [body] and [status] line, and a row of small [chips].
///
/// [trailing] defaults to a chevron; pass a menu button for owner-editable
/// lists.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.body,
    this.status,
    this.chips = const [],
    this.trailing,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final String? subtitle;
  final Widget? body;
  final Widget? status;
  final List<SummaryInfoChip> chips;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sub = subtitle;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: colorScheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                    if (body != null) ...[const SizedBox(height: 8), body!],
                    if (status != null) ...[const SizedBox(height: 8), status!],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 16, runSpacing: 6, children: chips),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing ??
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small icon + label fact shown under a [SummaryCard]'s body.
class SummaryInfoChip extends StatelessWidget {
  const SummaryInfoChip(this.icon, this.label, {super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

/// "1 week" / "2 weeks".
String pluralize(int n, String singular) => '$n $singular${n == 1 ? '' : 's'}';

/// Rest days are part of a program's schedule but not a session anyone trains,
/// so this is the number that says how much work a program is.
int countTrainingDays(Iterable<Iterable<bool>> restFlagsByWeek) =>
    restFlagsByWeek.expand((w) => w).where((isRest) => !isRest).length;

/// "Deadlift · Row · Curl  +2 more" from a list of exercise names.
String exercisePreview(List<String> names, {int max = 3}) {
  final shown = names.take(max).join(' · ');
  final more = names.length - max;
  return more > 0 ? '$shown  +$more more' : shown;
}
