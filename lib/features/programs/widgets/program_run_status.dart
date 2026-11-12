import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// A running program's state: the design system's status dot (orange with a
/// halo while in progress, gray while upcoming) and a quiet line, so the
/// program's name stays the loudest thing nearby. Shared by the Programs list
/// and the program screen so the two read the same.
class ProgramRunStatus extends StatelessWidget {
  const ProgramRunStatus({super.key, required this.upcoming, required this.date});

  final bool upcoming;
  final String date;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    final base = Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.fg3);
    return Row(
      children: [
        Container(
          key: const Key('program_run_status_dot'),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: upcoming ? palette.fg3 : palette.primary,
            boxShadow: upcoming ? null : [BoxShadow(color: palette.primarySubtle, spreadRadius: 3)],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: base,
              children: [
                TextSpan(
                  text: upcoming ? 'Upcoming' : 'In progress',
                  style: TextStyle(color: palette.fg1, fontWeight: FontWeight.w500),
                ),
                TextSpan(text: upcoming ? ' · starts $date' : ' · started $date'),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
