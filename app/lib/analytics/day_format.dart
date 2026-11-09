const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// A calendar day as "4 Nov 2026", or "4 Nov" without the year. Days are
/// stored as UTC midnight of the date, so the fields are read as stored.
String formatDay(DateTime d, {bool withYear = true}) =>
    '${d.day} ${_months[d.month - 1]}${withYear ? ' ${d.year}' : ''}';
