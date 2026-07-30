import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/core/theme/app_theme.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/categoria.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/providers/habit_providers.dart';
import 'package:habitbuilder_mobile/features/progress/domain/entities/progress_summary.dart';
import 'package:habitbuilder_mobile/features/progress/domain/entities/statistics_summary.dart';
import 'package:habitbuilder_mobile/features/progress/domain/repositories/progress_repository.dart';
import 'package:habitbuilder_mobile/features/progress/presentation/providers/progress_providers.dart';
import 'package:habitbuilder_mobile/features/progress/presentation/screens/progress_screen.dart';

void main() {
  testWidgets('renders summary metrics and heatmap from repository data', (
    tester,
  ) async {
    await _pump(tester, _FakeProgressRepository());

    expect(find.text('84%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('12 días'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
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
    expect(find.text('Progreso'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders statistics highlights and habit detail', (tester) async {
    await _pump(tester, _FakeProgressRepository());

    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();

    expect(find.text('84%'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Detalle por hábito'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Mejor racha'), findsOneWidget);
    expect(find.text('Leer 20 minutos'), findsNWidgets(2));
    expect(find.text('Meditar'), findsOneWidget);
    expect(find.text('Detalle por hábito'), findsOneWidget);
  });

  testWidgets('reloads statistics when filters change', (tester) async {
    final repository = _FakeProgressRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statistics-habit-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leer 20 minutos').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('statistics-category-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bienestar').last);
    await tester.pumpAndSettle();

    expect(repository.statisticsRequests.last.habitId, 'hab_001');
    expect(repository.statisticsRequests.last.categoryId, 'cat_001');
  });

  testWidgets('shows insufficient statistics and fits at 320x640', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = _FakeProgressRepository(insufficientStatistics: true);

    await _pump(tester, repository);
    await tester.tap(find.text('Estadísticas'));
    await tester.pumpAndSettle();

    expect(find.text('Aún no hay datos suficientes.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('announces summaries and fits 200% high-contrast text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();
    try {
      await _pump(tester, _FakeProgressRepository(), highContrast: true);
      await tester.scrollUntilVisible(
        find.text('84%'),
        180,
        scrollable: find.byType(Scrollable).last,
      );

      expect(
        find.bySemanticsLabel(
          'Cumplimiento semana, 84 por ciento, más 6 por ciento frente al '
          'periodo anterior, 28 de 35 completados',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byTooltip('27 jul · 100%'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byTooltip('27 jul · 100%'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeProgressRepository repository, {
  bool highContrast = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(repository),
        habitsListProvider.overrideWith((ref) async => [_habit()]),
        categoriesListProvider.overrideWith(
          (ref) async => const [Categoria(id: 'cat_001', nombre: 'Bienestar')],
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(highContrast: highContrast),
        home: const ProgressScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeProgressRepository implements ProgressRepository {
  _FakeProgressRepository({
    this.empty = false,
    this.insufficientStatistics = false,
  });

  final requests = <ProgressPeriod>[];
  final statisticsRequests = <StatisticsFilter>[];
  bool empty;
  bool insufficientStatistics;
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

  @override
  Future<StatisticsSummary> getStatistics(StatisticsFilter filter) async {
    statisticsRequests.add(filter);
    if (insufficientStatistics) {
      return StatisticsSummary(
        period: filter.period,
        from: DateTime(2026, 7, 27),
        to: DateTime(2026, 8, 2),
        completionRate: 0,
        bestStreak: 0,
        sufficientData: false,
        habits: const [],
      );
    }
    return StatisticsSummary(
      period: filter.period,
      from: DateTime(2026, 7, 27),
      to: DateTime(2026, 8, 2),
      completionRate: 0.84,
      bestStreak: 12,
      sufficientData: true,
      mostConsistent: const StatisticHighlight(
        id: 'hab_001',
        name: 'Leer 20 minutos',
        value: 0.92,
      ),
      mostSkipped: const StatisticHighlight(
        id: 'hab_002',
        name: 'Meditar',
        value: 3,
      ),
      habits: const [
        HabitStatistic(
          id: 'hab_001',
          name: 'Leer 20 minutos',
          completionRate: 0.92,
          streak: 12,
          skipped: 1,
        ),
      ],
    );
  }
}

Habito _habit() {
  final now = DateTime(2026, 7, 30);
  return Habito(
    id: 'hab_001',
    usuarioId: 'usr_001',
    nombre: 'Leer 20 minutos',
    fechaInicio: now,
    frecuencia: const FrecuenciaDiaria(),
    estado: HabitoEstado.activo,
    pausas: const [],
    fechaCreacion: now,
    fechaActualizacion: now,
    categoriaId: 'cat_001',
  );
}
