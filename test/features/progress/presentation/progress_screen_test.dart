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
  testWidgets('renders summary and per-habit progress from repository data', (
    tester,
  ) async {
    await _pump(tester, _FakeProgressRepository());

    expect(find.text('84%'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.text('12 días'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('12 días'), findsOneWidget);
    expect(find.text('28 días'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Progreso por hábito'), findsOneWidget);
    expect(find.text('Leer 20 minutos'), findsOneWidget);
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
    expect(find.text('Promedio por hábito (mes)'), findsOneWidget);
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
    expect(find.text('84%'), findsNWidgets(2));
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
      expect(
        find.bySemanticsLabel(
          'Promedio por hábito en semana, 84 por ciento, 1 hábitos con datos',
        ),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Progreso por hábito'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Progreso por hábito'), findsOneWidget);
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
        habits: const [
          HabitProgress(
            habitId: 'hab_001',
            completionRate: 0,
            currentStreak: 0,
            longestStreak: 0,
            hasData: false,
          ),
        ],
      );
    }
    return ProgressSummary(
      period: period,
      from: DateTime(2026, 7, 27),
      to: DateTime(2026, 8, 2),
      completionRate: 0.84,
      currentStreak: 12,
      longestStreak: 28,
      habits: const [
        HabitProgress(
          habitId: 'hab_001',
          completionRate: 0.84,
          currentStreak: 12,
          longestStreak: 28,
          hasData: true,
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
          completed: 28,
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
