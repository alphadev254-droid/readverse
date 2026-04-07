import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class Formatters {
  Formatters._();

  static String date(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);

  static String dateTime(DateTime date) =>
      DateFormat('MMM d, yyyy • h:mm a').format(date);

  static String timeAgo(DateTime date) => timeago.format(date);

  static String readingTime(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).round()}m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  static String pageProgress(int current, int total) =>
      'Page $current of $total';

  static String percentage(double value) =>
      '${(value * 100).round()}%';

  static String fileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
