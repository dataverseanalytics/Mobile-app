/// Lightweight formatters (no intl dependency needed yet).
abstract final class Fmt {
  static String thousands(num value) {
    final s = value.round().abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return value < 0 ? '-$b' : b.toString();
  }

  static String kcal(num v) => thousands(v);

  static String grams(num v) => '${v.round()} g';

  /// 1 → "1", 1.5 → "1.5", 0.25 → "0.25".
  static String servings(double s) =>
      s.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');

  static const _months = [
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
  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String weekdayShort(DateTime d) => _weekdays[d.weekday - 1];

  static String dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  static String longDate(DateTime d) => '${weekdayShort(d)}, ${dayMonth(d)}';

  static String time(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  static String greeting(DateTime d) => switch (d.hour) {
    < 5 => 'Good night',
    < 12 => 'Good morning',
    < 17 => 'Good afternoon',
    _ => 'Good evening',
  };
}
