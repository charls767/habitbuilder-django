import '../../domain/entities/progress_summary.dart';

class ProgressDayDto {
  const ProgressDayDto({
    required this.date,
    required this.completionRate,
    required this.completed,
    required this.scheduled,
  });

  factory ProgressDayDto.fromJson(Map<String, dynamic> json) {
    return ProgressDayDto(
      date: DateTime.parse(json['fecha'] as String),
      completionRate: (json['porcentajeCumplimiento'] as num).toDouble(),
      completed: json['completados'] as int,
      scheduled: json['programados'] as int,
    );
  }

  final DateTime date;
  final double completionRate;
  final int completed;
  final int scheduled;

  ProgressDay toDomain() => ProgressDay(
    date: date,
    completionRate: completionRate,
    completed: completed,
    scheduled: scheduled,
  );
}

class ProgressSummaryDto {
  const ProgressSummaryDto({
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

  factory ProgressSummaryDto.fromJson(Map<String, dynamic> json) {
    final periodValue = json['periodo'] as String;
    return ProgressSummaryDto(
      period: ProgressPeriod.values.firstWhere(
        (period) => period.apiValue == periodValue,
      ),
      from: DateTime.parse(json['desde'] as String),
      to: DateTime.parse(json['hasta'] as String),
      completionRate: (json['porcentajeCumplimiento'] as num).toDouble(),
      currentStreak: json['rachaActual'] as int,
      longestStreak: json['rachaMasLarga'] as int,
      completed: json['completados'] as int,
      scheduled: json['programados'] as int,
      changeVsPrevious: (json['cambioPeriodoAnterior'] as num).toDouble(),
      days: (json['dias'] as List<dynamic>)
          .map((item) => ProgressDayDto.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  final ProgressPeriod period;
  final DateTime from;
  final DateTime to;
  final double completionRate;
  final int currentStreak;
  final int longestStreak;
  final int completed;
  final int scheduled;
  final double changeVsPrevious;
  final List<ProgressDayDto> days;

  ProgressSummary toDomain() => ProgressSummary(
    period: period,
    from: from,
    to: to,
    completionRate: completionRate,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    completed: completed,
    scheduled: scheduled,
    changeVsPrevious: changeVsPrevious,
    days: days.map((day) => day.toDomain()).toList(growable: false),
  );
}
