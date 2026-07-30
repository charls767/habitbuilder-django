enum ProgressPeriod {
  week('semana', 'Semana'),
  month('mes', 'Mes');

  const ProgressPeriod(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class HabitProgress {
  const HabitProgress({
    required this.habitId,
    required this.completionRate,
    required this.currentStreak,
    required this.longestStreak,
    required this.hasData,
  });

  final String habitId;
  final double completionRate;
  final int currentStreak;
  final int longestStreak;
  final bool hasData;
}

class ProgressSummary {
  ProgressSummary({
    required this.period,
    required this.from,
    required this.to,
    required this.completionRate,
    required this.currentStreak,
    required this.longestStreak,
    required List<HabitProgress> habits,
  }) : habits = List<HabitProgress>.unmodifiable(habits);

  final ProgressPeriod period;
  final DateTime from;
  final DateTime to;
  final double completionRate;
  final int currentStreak;
  final int longestStreak;
  final List<HabitProgress> habits;

  bool get hasData => habits.any((habit) => habit.hasData);
}
