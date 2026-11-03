import 'package:intl/intl.dart';

import '../../../core/utils/weight_converter.dart';

typedef AxisTick = ({DateTime date, String label});

/// Most date labels the x-axis shows; denser ranges skip ticks evenly.
const _kMaxXTicks = 5;

/// Date labels for a progression chart running from [first] to [last].
///
/// - A year or more: one tick per new year (Jan 1), labelled "2024".
/// - Less than a year: one tick per month start, labelled "Mar", except
///   January, which shows the year so a year change stays readable.
/// - Within a single month: the first and last day, labelled "Mar 4".
///
/// Every tick falls inside [first]..[last], so it can be placed with the same
/// date-to-x mapping as the points.
List<AxisTick> progressionXTicks(DateTime first, DateTime last) {
  if (last.difference(first).inDays >= 365) {
    final years = [for (var y = first.year + 1; y <= last.year; y++) y];
    return _thin([for (final y in years) (date: DateTime(y), label: '$y')]);
  }

  final months = <AxisTick>[];
  var cursor = DateTime(first.year, first.month + 1);
  while (!cursor.isAfter(last)) {
    months.add((
      date: cursor,
      label: cursor.month == 1 ? '${cursor.year}' : DateFormat.MMM().format(cursor),
    ));
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  if (months.isNotEmpty) return _thin(months);

  final day = DateFormat.MMMd();
  final sameDay = first.year == last.year &&
      first.month == last.month &&
      first.day == last.day;
  return [
    (date: first, label: day.format(first)),
    if (!sameDay) (date: last, label: day.format(last)),
  ];
}

List<AxisTick> _thin(List<AxisTick> ticks) {
  final step = (ticks.length / _kMaxXTicks).ceil();
  if (step <= 1) return ticks;
  return [for (var i = 0; i < ticks.length; i += step) ticks[i]];
}

/// A compact weight for a y-axis label: whole pounds, or kg to one decimal
/// (trimmed). [unit] is 'kg' or 'lbs' — callers split a 'both' preference
/// into one axis per unit.
String formatAxisWeight(double weightKg, String unit) => unit == 'lbs'
    ? '${kgToLbs(weightKg).round()} lbs'
    : formatWeight(weightKg, 'kg');
