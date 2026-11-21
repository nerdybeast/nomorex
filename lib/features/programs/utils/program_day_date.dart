/// The calendar date a program day materializes to when a program is
/// started on [startDate]. [dayOffset] is `ProgramDay.dayOffset`: 7 × the
/// day's week index plus its place in the week, so every week takes 7
/// calendar days. Mirrors the date math the `start_program` RPC performs
/// server-side. Built from y/m/d, not Duration math, so a DST change can't
/// shift a day.
DateTime programDayDate(DateTime startDate, int dayOffset) =>
    DateTime(startDate.year, startDate.month, startDate.day + dayOffset);
