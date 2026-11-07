const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// "8 Nov 2026, 09:12" in the device's local time.
String formatLocalDateTime(DateTime t) {
  final l = t.toLocal();
  return '${l.day} ${_months[l.month - 1]} ${l.year}, '
      '${_two(l.hour)}:${_two(l.minute)}';
}

/// "2:45" for a duration under an hour.
String formatMinutesSeconds(Duration d) {
  final s = d.inSeconds;
  return '${s ~/ 60}:${_two(s % 60)}';
}
