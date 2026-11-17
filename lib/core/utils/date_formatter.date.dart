import 'package:intl/intl.dart';

class DateFormatter {
  DateFormatter._();

  static String full(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  static String short(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  static String month(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  static String day(DateTime date) {
    return DateFormat('EEE').format(date);
  }
}