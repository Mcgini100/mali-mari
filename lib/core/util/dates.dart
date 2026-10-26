/// Calendar helpers. Budgets run on calendar months.
class MonthRange {
  const MonthRange(this.year, this.month);

  factory MonthRange.of(DateTime d) => MonthRange(d.year, d.month);

  final int year;
  final int month;

  DateTime get start => DateTime(year, month);

  /// Exclusive end: the first instant of the next month.
  DateTime get end => DateTime(year, month + 1);

  int get days => DateTime(year, month + 1, 0).day;

  MonthRange get previous => MonthRange.of(DateTime(year, month - 1));
  MonthRange get next => MonthRange.of(DateTime(year, month + 1));

  bool contains(DateTime d) => !d.isBefore(start) && d.isBefore(end);

  bool isSameAs(MonthRange other) => other.year == year && other.month == month;

  @override
  bool operator ==(Object other) => other is MonthRange && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int daysBetween(DateTime a, DateTime b) => dateOnly(b).difference(dateOnly(a)).inDays;
