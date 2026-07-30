import '../entities/progress_summary.dart';
import '../entities/statistics_summary.dart';

abstract interface class ProgressRepository {
  Future<ProgressSummary> getSummary(ProgressPeriod period);

  Future<StatisticsSummary> getStatistics(StatisticsFilter filter);
}
