import 'package:intl/intl.dart';

class DateFormatter {
  static String formatChatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeFormat = DateFormat('HH:mm');
    final timeString = timeFormat.format(dateTime);

    if (messageDate == today) {
      // Today: show only time
      return timeString;
    } else if (messageDate == yesterday) {
      // Yesterday: show "เมื่อวาน" + time
      return 'เมื่อวาน $timeString';
    } else if (dateTime.year == now.year) {
      // This year: show date and time
      return DateFormat('dd/MM HH:mm').format(dateTime);
    } else {
      // Other years: show full date and time
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    }
  }
} 