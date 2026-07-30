enum ProgressPeriod {
  week('semana', 'Semana'),
  month('mes', 'Mes'),
  year('anio', 'Año');

  const ProgressPeriod(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class ProgressDay {
  const ProgressDay({
    required this.date,
    required this.completionRate,
    required this.completed,
    required this.scheduled,
  });

  final DateTime date;
  final double completionRate;
  final int completed;
  final int scheduled;
}

class ProgressSummary {
  const ProgressSummary({
    required this.period,
    required this.from,
    required this.to,
    required this.completionRate,
    required this.currentStreak,
    required this.longestStreak,
    required this.completed,
    required this.scheduled,
    required this.changeVsPrevious,
    required this.days,
  });

  final ProgressPeriod period;
  final DateTime from;
  final DateTime to;
  final double completionRate;
  final int currentStreak;
  final int longestStreak;
  final int completed;
  final int scheduled;
  final double changeVsPrevious;
  final List<ProgressDay> days;

  bool get hasData => scheduled > 0 || days.any((day) => day.scheduled > 0);
}
