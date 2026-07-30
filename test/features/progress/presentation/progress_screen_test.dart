import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/theme/app_theme.dart';
import 'package:habitbuilder_mobile/features/progress/domain/entities/progress_summary.dart';
import 'package:habitbuilder_mobile/features/progress/domain/repositories/progress_repository.dart';
import 'package:habitbuilder_mobile/features/progress/presentation/providers/progress_providers.dart';
import 'package:habitbuilder_mobile/features/progress/presentation/screens/progress_screen.dart';

void main() {
  testWidgets('renders summary metrics and heatmap from repository data', (
    tester,
  ) async {
    await _pump(tester, _FakeProgressRepository());

    expect(find.text('84%'), findsOneWidget);
    expect(find.text('12 días'), findsOneWidget);
    expect(find.text('28 días'), findsOneWidget);
    expect(find.text('28/35'), findsOneWidget);
    expect(find.text('Actividad del periodo'), findsOneWidget);
    expect(find.byTooltip('27 jul · 100%'), findsOneWidget);
  });

  testWidgets('defaults to week and reloads when period changes', (
    tester,
  ) async {
    final repository = _FakeProgressRepository();
    await _pump(tester, repository);

    expect(repository.requests, [ProgressPeriod.week]);
    await tester.tap(find.text('Mes'));
    await tester.pumpAndSettle();

    expect(repository.requests, [ProgressPeriod.week, ProgressPeriod.month]);
    expect(find.text('Cumplimiento mes'), findsOneWidget);
  });

  testWidgets('shows empty and retryable error states', (tester) async {
    final repository = _FakeProgressRepository(empty: true);
    await _pump(tester, repository);
    expect(find.text('Aún no hay datos para este periodo.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    repository
      ..empty = false
      ..failure = Exception('offline');
    await _pump(tester, repository);
    expect(find.text('Reintentar'), findsOneWidget);

    repository.failure = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('84%'), findsOneWidget);
  });

  testWidgets('fits progress controls at 320x640', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pump(tester, _FakeProgressRepository());

    expect(find.text('Semana'), findsOneWidget);
    expect(find.text('Progreso'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeProgressRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [progressRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(theme: AppTheme.light(), home: const ProgressScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeProgressRepository implements ProgressRepository {
  _FakeProgressRepository({this.empty = false});

  final requests = <ProgressPeriod>[];
  bool empty;
  Object? failure;

  @override
  Future<ProgressSummary> getSummary(ProgressPeriod period) async {
    requests.add(period);
    final error = failure;
    if (error != null) throw error;
    if (empty) {
      return ProgressSummary(
        period: period,
        from: DateTime(2026, 7, 27),
        to: DateTime(2026, 8, 2),
        completionRate: 0,
        currentStreak: 0,
        longestStreak: 0,
        completed: 0,
        scheduled: 0,
        changeVsPrevious: 0,
        days: const [],
      );
    }
    return ProgressSummary(
      period: period,
      from: DateTime(2026, 7, 27),
      to: DateTime(2026, 8, 2),
      completionRate: 0.84,
      currentStreak: 12,
      longestStreak: 28,
      completed: 28,
      scheduled: 35,
      changeVsPrevious: 0.06,
      days: [
        for (var index = 0; index < 7; index++)
          ProgressDay(
            date: DateTime(2026, 7, 27 + index),
            completionRate: index == 0 ? 1 : 0.8,
            completed: index == 0 ? 5 : 4,
            scheduled: 5,
          ),
      ],
    );
  }
}
