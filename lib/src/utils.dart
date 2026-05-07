import 'package:intl/intl.dart';

String formatDuration(int seconds) {
  final sign = seconds < 0 ? '-' : '';
  final value = seconds.abs();
  final minutes = value ~/ 60;
  final remainder = value % 60;
  return '$sign$minutes:${remainder.toString().padLeft(2, '0')}';
}

int? parseDuration(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split(':');
  if (parts.length == 1) {
    return int.tryParse(parts.first);
  }
  if (parts.length == 2) {
    final minutes = int.tryParse(parts[0]);
    final seconds = int.tryParse(parts[1]);
    if (minutes == null || seconds == null) return null;
    return minutes * 60 + seconds;
  }
  if (parts.length == 3) {
    final hours = int.tryParse(parts[0]);
    final minutes = int.tryParse(parts[1]);
    final seconds = int.tryParse(parts[2]);
    if (hours == null || minutes == null || seconds == null) return null;
    return hours * 3600 + minutes * 60 + seconds;
  }
  return null;
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
