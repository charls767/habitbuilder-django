import '../entities/progress_summary.dart';

abstract interface class ProgressRepository {
  Future<ProgressSummary> getSummary(ProgressPeriod period);
}
