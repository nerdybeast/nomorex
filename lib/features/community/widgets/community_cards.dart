import 'package:flutter/material.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/owner_name.dart';
import '../../../shared/widgets/summary_card.dart';
import '../../programs/models/program.dart';
import '../../workouts/models/workout.dart';

class CommunityProgramCard extends StatelessWidget {
  const CommunityProgramCard({super.key, required this.program, required this.onTap});

  final Program program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trainingDays = countTrainingDays(
      program.weeks.map((w) => w.days.map((d) => d.isRestDay)),
    );
    final description = program.description?.trim();
    return SummaryCard(
      icon: Icons.checklist_outlined,
      title: program.name,
      subtitle: 'by ${ownerDisplayName(program.ownerDisplayName)}',
      body: description == null || description.isEmpty
          ? null
          : Text(description, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      chips: [
        SummaryInfoChip(Icons.calendar_view_week_outlined, pluralize(program.weeks.length, 'week')),
        if (trainingDays > 0)
          SummaryInfoChip(Icons.fitness_center_outlined, pluralize(trainingDays, 'training day')),
      ],
    );
  }
}

class CommunityWorkoutCard extends StatelessWidget {
  const CommunityWorkoutCard({super.key, required this.workout, required this.onTap});

  final Workout workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final names = workout.exercises.map((e) => e.exerciseName).where((n) => n.isNotEmpty).toList();
    final text = names.isEmpty ? workout.notes?.trim() : exercisePreview(names);
    return SummaryCard(
      icon: Icons.fitness_center_outlined,
      title: workout.title,
      subtitle: 'by ${ownerDisplayName(workout.ownerDisplayName)}',
      body: text == null || text.isEmpty
          ? null
          : Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onTap,
      chips: [
        SummaryInfoChip(Icons.event_outlined, formatDate(workout.date)),
        SummaryInfoChip(Icons.list_alt_outlined, pluralize(workout.exercises.length, 'exercise')),
      ],
    );
  }
}
