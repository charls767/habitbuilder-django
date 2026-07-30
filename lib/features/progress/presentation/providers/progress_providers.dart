import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/datasources/progress_remote_data_source.dart';
import '../../data/repositories/progress_repository_impl.dart';
import '../../domain/entities/progress_summary.dart';
import '../../domain/entities/statistics_summary.dart';
import '../../domain/repositories/progress_repository.dart';

part 'progress_providers.g.dart';

@riverpod
ProgressRemoteDataSource progressRemoteDataSource(Ref ref) {
  return ProgressRemoteDataSource(ref.watch(dioProvider));
}

@riverpod
ProgressRepository progressRepository(Ref ref) {
  return ProgressRepositoryImpl(ref.watch(progressRemoteDataSourceProvider));
}

@riverpod
class SelectedProgressPeriod extends _$SelectedProgressPeriod {
  @override
  ProgressPeriod build() => ProgressPeriod.week;

  void select(ProgressPeriod period) => state = period;
}

@riverpod
Future<ProgressSummary> progressSummary(Ref ref) {
  final period = ref.watch(selectedProgressPeriodProvider);
  return ref.watch(progressRepositoryProvider).getSummary(period);
}

enum ProgressView { progress, statistics }

@riverpod
class SelectedProgressView extends _$SelectedProgressView {
  @override
  ProgressView build() => ProgressView.progress;

  void select(ProgressView view) => state = view;
}

@riverpod
class SelectedStatisticsFilter extends _$SelectedStatisticsFilter {
  @override
  StatisticsFilter build() =>
      const StatisticsFilter(period: ProgressPeriod.week);

  void selectPeriod(ProgressPeriod period) {
    state = state.copyWith(period: period);
  }

  void selectHabit(String? habitId) {
    state = state.copyWith(habitId: habitId, clearHabit: habitId == null);
  }

  void selectCategory(String? categoryId) {
    state = state.copyWith(
      categoryId: categoryId,
      clearCategory: categoryId == null,
    );
  }
}

@riverpod
Future<StatisticsSummary> statisticsSummary(Ref ref) {
  final filter = ref.watch(selectedStatisticsFilterProvider);
  return ref.watch(progressRepositoryProvider).getStatistics(filter);
}
