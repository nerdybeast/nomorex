/// The calendar date a program day materializes to when a program is
/// started on [startDate]. `position` is the day's global, 0-based order
/// across the whole program (`program_days.position`) — mirrors the date
/// math the `start_program` RPC performs server-side.
DateTime programDayDate(DateTime startDate, int position) =>
    startDate.add(Duration(days: position));
