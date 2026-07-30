import 'progress_summary.dart';

class StatisticsFilter {
  const StatisticsFilter({required this.period, this.habitId, this.categoryId});

  final ProgressPeriod period;
  final String? habitId;
  final String? categoryId;

  StatisticsFilter copyWith({
    ProgressPeriod? period,
    String? habitId,
    String? categoryId,
    bool clearHabit = false,
    bool clearCategory = false,
  }) {
    return StatisticsFilter(
      period: period ?? this.period,
      habitId: clearHabit ? null : habitId ?? this.habitId,
      categoryId: clearCategory ? null : categoryId ?? this.categoryId,
    );
  }
}

class StatisticHighlight {
  const StatisticHighlight({
    required this.id,
    required this.name,
    required this.value,
  });

  final String id;
  final String name;
  final double value;
}

class HabitStatistic {
  const HabitStatistic({
    required this.id,
    required this.name,
    required this.completionRate,
    required this.streak,
    required this.completed,
    required this.skipped,
  });

  final String id;
  final String name;
  final double completionRate;
  final int streak;
  final int completed;
  final int skipped;
}

class StatisticsSummary {
  StatisticsSummary({
    required this.period,
    required this.from,
    required this.to,
    required this.completionRate,
    required this.bestStreak,
    required this.sufficientData,
    required List<HabitStatistic> habits,
    this.mostConsistent,
    this.mostSkipped,
  }) : habits = List<HabitStatistic>.unmodifiable(habits);

  final ProgressPeriod period;
  final DateTime from;
  final DateTime to;
  final double completionRate;
  final int bestStreak;
  final bool sufficientData;
  final StatisticHighlight? mostConsistent;
  final StatisticHighlight? mostSkipped;
  final List<HabitStatistic> habits;
}
