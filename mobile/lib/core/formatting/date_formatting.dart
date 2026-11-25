import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const String kSpanishLocale = 'es_ES';

/// Parses an API date (`"yyyy-MM-dd"`, in the group's time zone) into a
/// date-only [DateTime] without any UTC conversion.
DateTime? parseApiDate(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

/// Formats a calendar date as `"yyyy-MM-dd"` for the API.
String formatApiDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Parses an API time of day (`"HH:mm"`, in the group's time zone).
TimeOfDay? parseApiTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  final parts = raw.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// Formats a [TimeOfDay] as `"HH:mm"` for the API.
String formatApiTime(TimeOfDay time) {
  final h = time.hour.toString().padLeft(2, '0');
  final m = time.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Formats a task's `dueDate` (and optional `dueTime`) for Spanish UI display.
///
/// Dates and times are kept in the group's time zone as supplied by the API.
String formatDueDateLabel(
  String dueDate, {
  String? dueTime,
  DateTime? now,
}) {
  final parsed = parseApiDate(dueDate);
  if (parsed == null) return dueDate;

  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);
  final difference = parsed.difference(today).inDays;

  final String datePart;
  if (difference == 0) {
    datePart = 'Hoy';
  } else if (difference == 1) {
    datePart = 'Mañana';
  } else if (difference == -1) {
    datePart = 'Ayer';
  } else if (parsed.year == today.year) {
    datePart = DateFormat('EEE, d MMM', kSpanishLocale).format(parsed);
  } else {
    datePart = DateFormat('d MMM yyyy', kSpanishLocale).format(parsed);
  }

  if (dueTime != null && dueTime.isNotEmpty) {
    return '$datePart · $dueTime';
  }
  return datePart;
}

/// Formats a date picker value in Spanish (e.g. `"sáb, 28 nov 2026"`).
String formatFullDate(DateTime date) {
  return DateFormat('EEE, d MMM yyyy', kSpanishLocale).format(date);
}

/// Formats a UTC timestamp from the API in the device's local time zone.
String formatUtcTimestampLocal(DateTime utcTimestamp) {
  final local = utcTimestamp.toLocal();
  return DateFormat('d MMM yyyy, HH:mm', kSpanishLocale).format(local);
}

/// Formats a UTC timestamp's date portion in the device's local time zone.
String formatUtcDateLocal(DateTime utcTimestamp) {
  final local = utcTimestamp.toLocal();
  return DateFormat('d MMM yyyy', kSpanishLocale).format(local);
}

/// Formats `reminderMinutesBefore` into a short Spanish label.
String formatReminderMinutes(int minutes) {
  return switch (minutes) {
    0 => 'A la hora',
    15 => '15 min antes',
    30 => '30 min antes',
    60 => '1 hora antes',
    1440 => '1 día antes',
    10080 => '1 semana antes',
    final m when m % 1440 == 0 => '${m ~/ 1440} días antes',
    final m when m % 60 == 0 => '${m ~/ 60} h antes',
    final m => '$m min antes',
  };
}
