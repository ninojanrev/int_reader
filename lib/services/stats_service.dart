import '../database/database_helper.dart';

/// Aggregated reading statistics, computed from real data
/// (the `daily_stats` table and the books table).
class ReadingStats {
  final double totalMinutes;
  final int currentStreakDays;
  final int bestStreakDays;
  final int daysReadTotal;
  final int daysReadThisMonth;
  final Map<DateTime, double> weekMinutes; // Monday..Sunday of current week

  const ReadingStats({
    required this.totalMinutes,
    required this.currentStreakDays,
    required this.bestStreakDays,
    required this.daysReadTotal,
    required this.daysReadThisMonth,
    required this.weekMinutes,
  });

  String get totalFormatted {
    final hours = totalMinutes ~/ 60;
    final mins = (totalMinutes % 60).round();
    if (hours == 0) return '${mins}m';
    return '$hours h $mins min';
  }
}

class StatsService {
  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<ReadingStats> compute() async {
    final stats = await dbHelper.getAllReadingStats();
    final minutesByDay = <DateTime, double>{
      for (final s in stats) _dateOnly(s.date): s.minutes,
    };

    final today = _dateOnly(DateTime.now());

    // Current streak: consecutive days ending today or yesterday.
    var current = 0;
    var cursor = today;
    if ((minutesByDay[cursor] ?? 0) <= 0) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while ((minutesByDay[cursor] ?? 0) > 0) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Best streak across all history.
    final sortedDays = minutesByDay.keys.where((d) => (minutesByDay[d] ?? 0) > 0).toList()..sort();
    var best = 0;
    var run = 0;
    for (var i = 0; i < sortedDays.length; i++) {
      if (i == 0 ||
          sortedDays[i].difference(sortedDays[i - 1]) == const Duration(days: 1)) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
    }

    // Week chart: Monday..Sunday of the current week.
    final weekdayMonday = today.subtract(Duration(days: today.weekday - 1));
    final weekMinutes = <DateTime, double>{
      for (var i = 0; i < 7; i++)
        weekdayMonday.add(Duration(days: i)): minutesByDay[weekdayMonday.add(Duration(days: i))] ?? 0.0,
    };

    // Days read this month.
    final daysThisMonth = minutesByDay.entries
        .where((e) =>
            (e.value) > 0 &&
            e.key.year == today.year &&
            e.key.month == today.month)
        .length;

    final total = await dbHelper.getTotalReadingMinutes();

    return ReadingStats(
      totalMinutes: total,
      currentStreakDays: current,
      bestStreakDays: best,
      daysReadTotal: minutesByDay.values.where((m) => m > 0).length,
      daysReadThisMonth: daysThisMonth,
      weekMinutes: weekMinutes,
    );
  }
}

/// Global singleton instance.
final statsService = StatsService();
