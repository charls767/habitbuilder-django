import '../../domain/entities/progress_summary.dart';
import '../../domain/entities/statistics_summary.dart';

class HabitStatisticDto {
  const HabitStatisticDto({
    required this.id,
    required this.name,
    required this.completionRate,
    required this.longestStreak,
    required this.completed,
    required this.skipped,
  });

  factory HabitStatisticDto.fromJson(Map<String, dynamic> json) {
    return HabitStatisticDto(
      id: json['habitoId'] as String,
      name: json['nombre'] as String,
      completionRate: (json['porcentaje'] as num).toDouble() / 100,
      longestStreak: json['rachaMasLarga'] as int,
      completed: json['totalHecho'] as int,
      skipped: json['totalOmitido'] as int,
    );
  }

  final String id;
  final String name;
  final double completionRate;
  final int longestStreak;
  final int completed;
  final int skipped;

  HabitStatistic toDomain() => HabitStatistic(
    id: id,
    name: name,
    completionRate: completionRate,
    streak: longestStreak,
    completed: completed,
    skipped: skipped,
  );
}

class StatisticsSummaryDto {
  const StatisticsSummaryDto({
    required this.period,
    required this.from,
    required this.to,
    required this.completionRate,
    required this.bestStreak,
    required this.sufficientData,
    required this.mostConsistent,
    required this.mostSkipped,
  });

  factory StatisticsSummaryDto.fromJson(
    Map<String, dynamic> json,
    ProgressPeriod requestedPeriod,
  ) {
    return StatisticsSummaryDto(
      period: requestedPeriod,
      from: DateTime.parse(json['periodoDesde'] as String),
      to: DateTime.parse(json['periodoHasta'] as String),
      completionRate: (json['porcentaje'] as num).toDouble() / 100,
      bestStreak: json['mejorRacha'] as int,
      sufficientData: json['estado'] == 'con_datos',
      mostConsistent: (json['masConsistentes'] as List<dynamic>)
          .map(
            (item) => HabitStatisticDto.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      mostSkipped: (json['masOmitidos'] as List<dynamic>)
          .map(
            (item) => HabitStatisticDto.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  final ProgressPeriod period;
  final DateTime from;
  final DateTime to;
  final double completionRate;
  final int bestStreak;
  final bool sufficientData;
  final List<HabitStatisticDto> mostConsistent;
  final List<HabitStatisticDto> mostSkipped;

  StatisticsSummary toDomain() {
    final habitsById = <String, HabitStatisticDto>{
      for (final habit in [...mostConsistent, ...mostSkipped]) habit.id: habit,
    };
    return StatisticsSummary(
      period: period,
      from: from,
      to: to,
      completionRate: completionRate,
      bestStreak: bestStreak,
      sufficientData: sufficientData,
      mostConsistent: mostConsistent.isEmpty
          ? null
          : StatisticHighlight(
              id: mostConsistent.first.id,
              name: mostConsistent.first.name,
              value: mostConsistent.first.completionRate,
            ),
      mostSkipped: mostSkipped.isEmpty
          ? null
          : StatisticHighlight(
              id: mostSkipped.first.id,
              name: mostSkipped.first.name,
              value: mostSkipped.first.skipped.toDouble(),
            ),
      habits: habitsById.values
          .map((habit) => habit.toDomain())
          .toList(growable: false),
    );
  }
}
