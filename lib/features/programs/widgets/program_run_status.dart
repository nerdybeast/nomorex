import 'package:material_ui/material_ui.dart';
import '../../../core/theme/app_theme.dart';

/// A running program's state: the design system's status dot (orange with a
/// halo while in progress, gray while upcoming) and a quiet line, so the
/// program's name stays the loudest thing nearby. Shared by the Programs list
/// and the program screen so the two read the same.
///
/// Given [week] ("Week 2 of 6"), a run that has started leads with where it
/// is rather than when it began, and [today] ("Day 3 today", "Rest day")
/// follows it. [finished] is a run whose last week has passed but which
/// nobody has completed: "Schedule finished", with a check where the dot
/// would be, since the work is done rather than paused.
class ProgramRunStatus extends StatelessWidget {
  const ProgramRunStatus({
    super.key,
    required this.upcoming,
    required this.date,
    this.week,
    this.today,
    this.finished = false,
  });

  final bool upcoming;
  final String date;
  final String? week;
  final String? today;
  final bool finished;

  @override
  Widget build(BuildContext context) {
    final palette = NomorexTokens.of(context).palette;
    final base = Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.fg3);
    return Row(
      // The dot stays level with the first line when the text wraps.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (finished)
          // Done, not idle: a check where the dot would be.
          Padding(
            key: const Key('program_run_status_done'),
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.check, size: 14, color: palette.fg2),
          )
        else
          Container(
            key: const Key('program_run_status_dot'),
            // Centers the 8px dot on the first line of body-small text.
            margin: const EdgeInsets.only(top: 5),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: upcoming ? palette.fg3 : palette.primary,
              boxShadow: upcoming ? null : [BoxShadow(color: palette.primarySubtle, spreadRadius: 3)],
            ),
          ),
        SizedBox(width: finished ? 4 : 8),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: base,
              children: [
                TextSpan(
                  text: upcoming ? 'Upcoming' : (finished ? 'Schedule finished' : (week ?? 'In progress')),
                  style: TextStyle(color: palette.fg1, fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: upcoming
                      ? ' · starts $date'
                      : finished
                      ? ''
                      : week == null
                      ? ' · started $date'
                      : (today == null ? '' : ' · $today'),
                ),
              ],
            ),
            // Two lines, so a rest day's "next session tomorrow" isn't cut
            // off on a phone.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
