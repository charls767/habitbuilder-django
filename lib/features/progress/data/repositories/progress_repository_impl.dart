import '../../domain/entities/progress_summary.dart';
import '../../domain/entities/statistics_summary.dart';
import '../../domain/repositories/progress_repository.dart';
import '../datasources/progress_remote_data_source.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  const ProgressRepositoryImpl(this._remote);

  final ProgressRemoteDataSource _remote;

  @override
  Future<ProgressSummary> getSummary(ProgressPeriod period) async {
    return (await _remote.getSummary(period)).toDomain();
  }

  @override
  Future<StatisticsSummary> getStatistics(StatisticsFilter filter) async {
    return (await _remote.getStatistics(filter)).toDomain();
  }
}
