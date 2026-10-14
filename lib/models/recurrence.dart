/// Recurrence rule kinds. Index order is the wire format shared with Kotlin —
/// never reorder these.
enum RecurrenceKind {
  once,
  weekly,
  everyNWeeks,
  monthlyNthWeekday,
  monthlyDayOfMonth,
}

RecurrenceKind recurrenceKindFromCode(int code) =>
    (code >= 0 && code < RecurrenceKind.values.length)
    ? RecurrenceKind.values[code]
    : RecurrenceKind.once;

/// `-1` means "last" (e.g. last Friday of the month).
const int kLastWeekOfMonth = -1;

const List<int> kNthOptions = [1, 2, 3, 4, kLastWeekOfMonth];
const List<int> kIntervalWeekOptions = [2, 3, 4];

String nthLabel(int nth) => switch (nth) {
  kLastWeekOfMonth => 'Last',
  1 => '1st',
  2 => '2nd',
  3 => '3rd',
  _ => '${nth}th',
};

String ordinalDay(int day) {
  if (day >= 11 && day <= 13) return '${day}th';
  return switch (day % 10) {
    1 => '${day}st',
    2 => '${day}nd',
    3 => '${day}rd',
    _ => '${day}th',
  };
}
