/// The programme begins on January 1, 2027.
final DateTime appStartDate = DateTime(2027, 1, 1);

/// Current app date, clamped to the programme start date before launch.
DateTime appDateNow() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.isBefore(appStartDate) ? appStartDate : now;
}

/// Today's date at midnight according to the app's programme calendar.
DateTime appToday() {
  final now = appDateNow();
  return DateTime(now.year, now.month, now.day);
}
