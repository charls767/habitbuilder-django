import '../../domain/entities/progress_summary.dart';
import '../../domain/entities/statistics_summary.dart';

class StatisticHighlightDto {
  const StatisticHighlightDto({
    required this.id,
    required this.name,
    required this.value,
  });

  factory StatisticHighlightDto.fromJson(Map<String, dynamic> json) {
    return StatisticHighlightDto(
      id: json['id'] as String,
      name: json['nombre'] as String,
      value: (json['valor'] as num).toDouble(),
    );
  }

  final String id;
  final String name;
  final double value;

  StatisticHighlight toDomain() =>
      StatisticHighlight(id: id, name: name, value: value);
}

class HabitStatisticDto {
  const HabitStatisticDto({
    required this.id,
    required this.name,
    required this.completionRate,
    required this.streak,
    required this.skipped,
  });

  factory HabitStatisticDto.fromJson(Map<String, dynamic> json) {
    return HabitStatisticDto(
      id: json['id'] as String,
      name: json['nombre'] as String,
      completionRate: (json['porcentajeCumplimiento'] as num).toDouble(),
      streak: json['racha'] as int,
      skipped: json['omitidos'] as int,
    );
  }

  final String id;
  final String name;
  final double completionRate;
  final int streak;
  final int skipped;

  HabitStatistic toDomain() => HabitStatistic(
    id: id,
    name: name,
    completionRate: completionRate,
    streak: streak,
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
    required this.habits,
    this.mostConsistent,
    this.mostSkipped,
  });

  factory StatisticsSummaryDto.fromJson(Map<String, dynamic> json) {
    final periodValue = json['periodo'] as String;
    final mostConsistent = json['habitoMasConstante'];
    final mostSkipped = json['habitoMasOmitido'];
    return StatisticsSummaryDto(
      period: ProgressPeriod.values.firstWhere(
        (period) => period.apiValue == periodValue,
      ),
      from: DateTime.parse(json['desde'] as String),
      to: DateTime.parse(json['hasta'] as String),
      completionRate: (json['porcentajeCumplimiento'] as num).toDouble(),
      bestStreak: json['mejorRacha'] as int,
      sufficientData: json['suficientesDatos'] as bool,
      mostConsistent: mostConsistent == null
          ? null
          : StatisticHighlightDto.fromJson(
              mostConsistent as Map<String, dynamic>,
            ),
      mostSkipped: mostSkipped == null
          ? null
          : StatisticHighlightDto.fromJson(mostSkipped as Map<String, dynamic>),
      habits: (json['habitos'] as List<dynamic>)
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
  final StatisticHighlightDto? mostConsistent;
  final StatisticHighlightDto? mostSkipped;
  final List<HabitStatisticDto> habits;

  StatisticsSummary toDomain() => StatisticsSummary(
    period: period,
    from: from,
    to: to,
    completionRate: completionRate,
    bestStreak: bestStreak,
    sufficientData: sufficientData,
    mostConsistent: mostConsistent?.toDomain(),
    mostSkipped: mostSkipped?.toDomain(),
    habits: habits.map((habit) => habit.toDomain()).toList(growable: false),
  );
}
