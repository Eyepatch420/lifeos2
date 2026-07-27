import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Normalise any DateTime to midnight so it can be used as a map key.
DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) =>
    dayKey(d).subtract(Duration(days: d.weekday - 1));

DateTime startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
DateTime endOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

int daysInMonth(DateTime d) => endOfMonth(d).day;
int daysLeftInMonth(DateTime d) => daysInMonth(d) - d.day;

String greetingFor(DateTime now) {
  if (now.hour < 12) return 'Good morning';
  if (now.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

final DateFormat fmtLongDate = DateFormat('EEEE, d MMMM yyyy');
final DateFormat fmtShortDate = DateFormat('d MMM');
final DateFormat fmtMonthYear = DateFormat('MMMM yyyy');

/// Filename-safe month stamp, e.g. "2026-07".
final DateFormat fmtMonthKey = DateFormat('yyyy-MM');
final DateFormat fmtMonthShort = DateFormat('MMM');
final DateFormat fmtTime = DateFormat('h:mm a');
final DateFormat fmtDayNum = DateFormat('d');
final DateFormat fmtDayName = DateFormat('EEE');

String formatTimeOfDay(TimeOfDay t) {
  final DateTime d = DateTime(2000, 1, 1, t.hour, t.minute);
  return fmtTime.format(d);
}

/// "Today", "Yesterday", "Tomorrow" or a short date.
String relativeDayLabel(DateTime d, DateTime now) {
  final int diff = dayKey(d).difference(dayKey(now)).inDays;
  if (diff == 0) return 'Today';
  if (diff == -1) return 'Yesterday';
  if (diff == 1) return 'Tomorrow';
  return fmtShortDate.format(d);
}

/// Human "in 45 min" / "in 3 days" / "2 days ago".
String relativeTimeLabel(DateTime target, DateTime now) {
  final Duration diff = target.difference(now);
  if (diff.isNegative) {
    final Duration past = now.difference(target);
    if (past.inMinutes < 60) return '${past.inMinutes} min ago';
    if (past.inHours < 24) return '${past.inHours} hr ago';
    return '${past.inDays} days ago';
  }
  if (diff.inMinutes < 60) return 'in ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'in ${diff.inHours} hr';
  return 'in ${diff.inDays} days';
}

/// Indian-style currency formatting used throughout the app.
String formatRupees(num value, {bool decimals = false}) {
  final NumberFormat f = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: decimals ? 2 : 0,
  );
  return f.format(value);
}

/// Compact form for headline figures: ₹28k, ₹44.9L.
String formatRupeesCompact(num value) {
  if (value.abs() >= 10000000) {
    return '₹${(value / 10000000).toStringAsFixed(1)}Cr';
  }
  if (value.abs() >= 100000) {
    return '₹${(value / 100000).toStringAsFixed(1)}L';
  }
  if (value.abs() >= 1000) {
    return '₹${(value / 1000).toStringAsFixed(value.abs() >= 10000 ? 0 : 1)}k';
  }
  return formatRupees(value);
}
