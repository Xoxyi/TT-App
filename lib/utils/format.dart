const List<String> _monthsShort = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

const List<String> _monthsLong = <String>[
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const List<String> _weekdays = <String>[
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

String monthShort(int month) => _monthsShort[(month - 1) % 12];

/// "17 Oct"
String shortDate(DateTime d) => '${d.day} ${monthShort(d.month)}';

/// "16 Oct 2026"
String fullDate(DateTime d) => '${d.day} ${monthShort(d.month)} ${d.year}';

/// "15:30"
String clock(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// "Sat 24 Oct"
String dayDate(DateTime d) => '${_weekdays[d.weekday - 1].substring(0, 3)} ${d.day} ${monthShort(d.month)}';

/// "Saturday, 17 October"
String longDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_monthsLong[d.month - 1]}';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// "today", "tomorrow", "in 5 days", "3 days ago"
String relativeDay(DateTime d, {DateTime? now}) {
  final diff = _day(d).difference(_day(now ?? DateTime.now())).inDays;
  if (diff == 0) return 'today';
  if (diff == 1) return 'tomorrow';
  if (diff == -1) return 'yesterday';
  return diff > 0 ? 'in $diff days' : '${-diff} days ago';
}

/// Home screen headline with a table-tennis twist, changing through the day.
String greeting(DateTime now) {
  if (now.hour < 12) return 'Ready to serve?';
  if (now.hour < 18) return 'Game on!';
  return 'One more rally?';
}

/// 1742 -> "1,742"
String thousands(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return n < 0 ? '-$buf' : buf.toString();
}

/// Start of the current table-tennis season (1 September).
DateTime seasonStart(DateTime now) =>
    DateTime(now.month >= 9 ? now.year : now.year - 1, 9, 1);
