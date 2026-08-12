import 'package:intl/intl.dart';

String formatDate(DateTime date) {
  return DateFormat.yMMMd().format(date);
}

String formatTime(DateTime dateTime) {
  return DateFormat.jm().format(dateTime.toLocal());
}
