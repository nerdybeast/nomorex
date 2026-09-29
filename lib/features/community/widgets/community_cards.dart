import 'package:flutter/material.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/owner_name.dart';
import '../../programs/models/program.dart';
import '../../workouts/models/workout.dart';

String _plural(int n, String singular) => '$n $singular${n == 1 ? '' : 's'}';

/// Shared chrome for a Community list entry: an icon badge, a title, the
/// author line, optional supporting text, and a row of small facts.
class _CommunityCard extends StatelessWidget {
  const _CommunityCard({
    required this.icon,
    required this.title,
    required this.author,
    required this.chips,
    required this.onTap,
    this.body,
  });

  final IconData icon;
  final String title;
  final String author;
  final List<_InfoChip> chips;
  final VoidCallback onTap;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant);
    final text = body?.trim();

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
                    const SizedBox(height: 2),
                    Text(author, style: muted),
                    if (text != null && text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                    if (chips.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 16, runSpacing: 6, children: chips),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
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

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.icon, this.label);

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

class CommunityProgramCard extends StatelessWidget {
  const CommunityProgramCard({super.key, required this.program, required this.onTap});

  final Program program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final weeks = program.weeks.length;
    // Rest days are part of the schedule but not a session anyone trains, so
    // "training days" is the number that says how much work the program is.
    final trainingDays = program.weeks
        .expand((w) => w.days)
        .where((d) => !d.isRestDay)
        .length;
    return _CommunityCard(
      icon: Icons.checklist_outlined,
      title: program.name,
      author: 'by ${ownerDisplayName(program.ownerDisplayName)}',
      body: program.description,
      onTap: onTap,
      chips: [
        _InfoChip(Icons.calendar_view_week_outlined, _plural(weeks, 'week')),
        if (trainingDays > 0)
          _InfoChip(Icons.fitness_center_outlined, _plural(trainingDays, 'training day')),
      ],
    );
  }
}

class CommunityWorkoutCard extends StatelessWidget {
  const CommunityWorkoutCard({super.key, required this.workout, required this.onTap});

  final Workout workout;
  final VoidCallback onTap;

  static const _previewCount = 3;

  @override
  Widget build(BuildContext context) {
    final names = workout.exercises
        .map((e) => e.exerciseName)
        .where((n) => n.isNotEmpty)
        .toList();
    final preview = names.take(_previewCount).join(' · ');
    final more = names.length - _previewCount;
    return _CommunityCard(
      icon: Icons.fitness_center_outlined,
      title: workout.title,
      author: 'by ${ownerDisplayName(workout.ownerDisplayName)}',
      body: names.isEmpty ? workout.notes : (more > 0 ? '$preview  +$more more' : preview),
      onTap: onTap,
      chips: [
        _InfoChip(Icons.event_outlined, formatDate(workout.date)),
        _InfoChip(Icons.list_alt_outlined, _plural(workout.exercises.length, 'exercise')),
      ],
    );
  }
}
