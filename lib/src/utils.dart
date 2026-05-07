import 'package:intl/intl.dart';

String formatDuration(int seconds) {
  final sign = seconds < 0 ? '-' : '';
  final value = seconds.abs();
  final minutes = value ~/ 60;
  final remainder = value % 60;
  return '$sign$minutes:${remainder.toString().padLeft(2, '0')}';
}

String formatSigned(int seconds) {
  if (seconds >= 0) return formatDuration(seconds);
  return '-${formatDuration(seconds.abs())}';
}

T? firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

final dateFormat = DateFormat('MMM d, yyyy h:mm a');
final shortDate = DateFormat('M/d/yy');
