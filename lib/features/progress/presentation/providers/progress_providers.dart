import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/datasources/progress_remote_data_source.dart';
import '../../data/repositories/progress_repository_impl.dart';
import '../../domain/entities/progress_summary.dart';
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
