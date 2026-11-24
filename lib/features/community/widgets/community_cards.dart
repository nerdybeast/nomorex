import 'package:material_ui/material_ui.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/owner_name.dart';
import '../../../shared/widgets/summary_card.dart';
import '../../programs/models/program.dart';
import '../../programs/utils/program_stats.dart';
import '../../workouts/models/workout.dart';

class CommunityProgramCard extends StatelessWidget {
  const CommunityProgramCard({super.key, required this.program, required this.onTap});

  final Program program;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final description = program.description?.trim();
    final daysPerWeek = daysPerWeekLabel([for (final w in program.weeks) StatsWeek.fromWeek(w)]);
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
        // How many days a week it asks for, as on the Programs list.
        if (daysPerWeek != null) SummaryInfoChip(Icons.today_outlined, daysPerWeek),
        SummaryInfoChip(Icons.event_outlined, formatDate(program.createdAt)),
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
