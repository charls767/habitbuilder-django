import '../../domain/entities/progress_summary.dart';

class HabitProgressDto {
  const HabitProgressDto({
    required this.habitId,
    required this.from,
    required this.to,
    required this.completionRate,
    required this.currentStreak,
    required this.longestStreak,
    required this.hasData,
  });

  factory HabitProgressDto.fromJson(Map<String, dynamic> json) {
    return HabitProgressDto(
      habitId: json['habitoId'] as String,
      from: DateTime.parse(json['periodoDesde'] as String),
      to: DateTime.parse(json['periodoHasta'] as String),
      completionRate: (json['porcentaje'] as num).toDouble() / 100,
      currentStreak: json['rachaActual'] as int,
      longestStreak: json['rachaMasLarga'] as int,
      hasData: json['estado'] == 'con_datos',
    );
  }

  final String habitId;
  final DateTime from;
  final DateTime to;
  final double completionRate;
  final int currentStreak;
  final int longestStreak;
  final bool hasData;

  HabitProgress toDomain() => HabitProgress(
    habitId: habitId,
    completionRate: completionRate,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    hasData: hasData,
  );
}

class ProgressSummaryDto {
  const ProgressSummaryDto({
    required this.period,
    required this.from,
    required this.to,
    required this.habits,
  });

  factory ProgressSummaryDto.fromJson(
    List<dynamic> json,
    ProgressPeriod requestedPeriod, {
    DateTime? fallbackDate,
  }) {
    final habits = json
        .map((item) => HabitProgressDto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final fallback = fallbackDate ?? DateTime.now();
    return ProgressSummaryDto(
      period: requestedPeriod,
      from: habits.isEmpty ? fallback : habits.first.from,
      to: habits.isEmpty ? fallback : habits.first.to,
      habits: habits,
    );
  }

  final ProgressPeriod period;
  final DateTime from;
  final DateTime to;
  final List<HabitProgressDto> habits;

  ProgressSummary toDomain() {
    final withData = habits.where((habit) => habit.hasData).toList();
    final completionRate = withData.isEmpty
        ? 0.0
        : withData
                  .map((habit) => habit.completionRate)
                  .reduce((left, right) => left + right) /
              withData.length;
    final currentStreak = withData.fold(
      0,
      (best, habit) => habit.currentStreak > best ? habit.currentStreak : best,
    );
    final longestStreak = withData.fold(
      0,
      (best, habit) => habit.longestStreak > best ? habit.longestStreak : best,
    );

    return ProgressSummary(
      period: period,
      from: from,
      to: to,
      completionRate: completionRate,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      habits: habits.map((habit) => habit.toDomain()).toList(growable: false),
    );
  }
}
