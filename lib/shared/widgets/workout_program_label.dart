import 'package:material_ui/material_ui.dart';
import '../../core/theme/app_theme.dart';

/// "Which program is this workout part of": the program's name with a
/// checklist icon, or a dimmer "Standalone" with a dumbbell when it isn't part
/// of one. Shown under a workout's title on the dashboard cards.
class WorkoutProgramLabel extends StatelessWidget {
  const WorkoutProgramLabel({super.key, required this.label, this.isStandalone = false});

  final String label;
  final bool isStandalone;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    final color = isStandalone ? palette.fg3 : palette.fg2;
    return Row(
      key: const Key('workout_program_label'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isStandalone ? Icons.fitness_center : Icons.checklist_outlined, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
