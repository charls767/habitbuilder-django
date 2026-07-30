import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../../habits/domain/entities/categoria.dart';
import '../../../habits/domain/entities/habito.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../domain/entities/progress_summary.dart';
import '../../domain/entities/statistics_summary.dart';
import '../providers/progress_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedView = ref.watch(selectedProgressViewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tu progreso')),
      body: AppContent(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ProgressView>(
                  segments: const [
                    ButtonSegment(
                      value: ProgressView.progress,
                      icon: Icon(Icons.auto_graph_outlined),
                      label: Text('Progreso'),
                    ),
                    ButtonSegment(
                      value: ProgressView.statistics,
                      icon: Icon(Icons.bar_chart_outlined),
                      label: Text('Estadísticas'),
                    ),
                  ],
                  selected: {selectedView},
                  showSelectedIcon: false,
                  onSelectionChanged: (values) => ref
                      .read(selectedProgressViewProvider.notifier)
                      .select(values.first),
                ),
              ),
            ),
            Expanded(
              child: selectedView == ProgressView.progress
                  ? const _ProgressBody()
                  : const _StatisticsBody(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppDestinationBar(selectedIndex: 3),
    );
  }
}

class _ProgressBody extends ConsumerWidget {
  const _ProgressBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedProgressPeriodProvider);
    final summary = ref.watch(progressSummaryProvider);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.refresh(progressSummaryProvider.future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            sliver: SliverToBoxAdapter(
              child: _PeriodSelector(
                selected: period,
                onSelected: (value) => ref
                    .read(selectedProgressPeriodProvider.notifier)
                    .select(value),
              ),
            ),
          ),
          summary.when(
            data: (value) => value.hasData
                ? SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 104),
                    sliver: SliverList.list(
                      children: [
                        _CompletionCard(summary: value),
                        const SizedBox(height: 14),
                        _HeatmapCard(summary: value),
                        const SizedBox(height: 14),
                        _Metrics(summary: value),
                      ],
                    ),
                  )
                : const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyProgress(),
                  ),
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _ProgressError(
                onRetry: () => ref.invalidate(progressSummaryProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsBody extends ConsumerWidget {
  const _StatisticsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(selectedStatisticsFilterProvider);
    final summary = ref.watch(statisticsSummaryProvider);
    final habits = ref.watch(habitsListProvider).value ?? const <Habito>[];
    final categories =
        ref.watch(categoriesListProvider).value ?? const <Categoria>[];
    final filterController = ref.read(
      selectedStatisticsFilterProvider.notifier,
    );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.refresh(statisticsSummaryProvider.future),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            sliver: SliverList.list(
              children: [
                _PeriodSelector(
                  selected: filter.period,
                  onSelected: filterController.selectPeriod,
                ),
                const SizedBox(height: 12),
                _StatisticsFilters(
                  habits: habits,
                  categories: categories,
                  habitId: filter.habitId,
                  categoryId: filter.categoryId,
                  onHabitChanged: filterController.selectHabit,
                  onCategoryChanged: filterController.selectCategory,
                ),
              ],
            ),
          ),
          summary.when(
            data: (value) => value.sufficientData
                ? SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 104),
                    sliver: SliverList.list(
                      children: [
                        _StatisticsCompletionCard(summary: value),
                        const SizedBox(height: 14),
                        _StatisticsHighlights(summary: value),
                        if (value.habits.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _HabitStatisticsCard(habits: value.habits),
                        ],
                      ],
                    ),
                  )
                : const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _InsufficientStatistics(),
                  ),
            loading: () => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: _ProgressError(
                onRetry: () => ref.invalidate(statisticsSummaryProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatisticsFilters extends StatelessWidget {
  const _StatisticsFilters({
    required this.habits,
    required this.categories,
    required this.habitId,
    required this.categoryId,
    required this.onHabitChanged,
    required this.onCategoryChanged,
  });

  final List<Habito> habits;
  final List<Categoria> categories;
  final String? habitId;
  final String? categoryId;
  final ValueChanged<String?> onHabitChanged;
  final ValueChanged<String?> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fields = [
          DropdownButtonFormField<String?>(
            key: const ValueKey('statistics-habit-filter'),
            initialValue: habits.any((habit) => habit.id == habitId)
                ? habitId
                : null,
            decoration: const InputDecoration(
              labelText: 'Hábito',
              prefixIcon: Icon(Icons.check_circle_outline),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              for (final habit in habits)
                DropdownMenuItem(
                  value: habit.id,
                  child: Text(habit.nombre, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onHabitChanged,
          ),
          DropdownButtonFormField<String?>(
            key: const ValueKey('statistics-category-filter'),
            initialValue:
                categories.any((category) => category.id == categoryId)
                ? categoryId
                : null,
            decoration: const InputDecoration(
              labelText: 'Categoría',
              prefixIcon: Icon(Icons.sell_outlined),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas')),
              for (final category in categories)
                DropdownMenuItem(
                  value: category.id,
                  child: Text(category.nombre, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onCategoryChanged,
          ),
        ];
        if (constraints.maxWidth < 560) {
          return Column(
            children: [fields.first, const SizedBox(height: 10), fields.last],
          );
        }
        return Row(
          children: [
            Expanded(child: fields.first),
            const SizedBox(width: 12),
            Expanded(child: fields.last),
          ],
        );
      },
    );
  }
}

class _StatisticsCompletionCard extends StatelessWidget {
  const _StatisticsCompletionCard({required this.summary});

  final StatisticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final percentage = (summary.completionRate * 100).round();
    return Semantics(
      container: true,
      label:
          'Cumplimiento filtrado $percentage por ciento, '
          'del ${_shortDate(summary.from)} al ${_shortDate(summary.to)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cumplimiento filtrado',
                    style: Theme.of(
                      context,
                    ).textTheme.labelLarge?.copyWith(color: AppColors.accent),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dateRange(summary.from, summary.to),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
            Text(
              '$percentage%',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsHighlights extends StatelessWidget {
  const _StatisticsHighlights({required this.summary});

  final StatisticsSummary summary;

  @override
  Widget build(BuildContext context) {
    final mostConsistent = summary.mostConsistent;
    final mostSkipped = summary.mostSkipped;
    final cards = [
      _StatisticHighlightCard(
        icon: Icons.emoji_events_outlined,
        label: 'Mejor racha',
        value: '${summary.bestStreak} días',
      ),
      _StatisticHighlightCard(
        icon: Icons.trending_up,
        label: 'Más constante',
        value: mostConsistent?.name ?? 'Sin datos',
        detail: mostConsistent == null
            ? null
            : '${(mostConsistent.value * 100).round()}%',
      ),
      _StatisticHighlightCard(
        icon: Icons.remove_circle_outline,
        label: 'Más omitido',
        value: mostSkipped?.name ?? 'Sin datos',
        detail: mostSkipped == null
            ? null
            : '${mostSkipped.value.round()} registros',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560 ? 1 : 3;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: columns == 1 ? 2.7 : 1.55,
          children: cards,
        );
      },
    );
  }
}

class _StatisticHighlightCard extends StatelessWidget {
  const _StatisticHighlightCard({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final semanticDetail = detail == null ? '' : ', $detail';
    return Semantics(
      label: '$label, $value$semanticDetail',
      excludeSemantics: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (detail != null)
                      Text(
                        detail!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitStatisticsCard extends StatelessWidget {
  const _HabitStatisticsCard({required this.habits});

  final List<HabitStatistic> habits;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalle por hábito',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < habits.length; index++) ...[
              _HabitStatisticRow(statistic: habits[index]),
              if (index < habits.length - 1) const Divider(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class _HabitStatisticRow extends StatelessWidget {
  const _HabitStatisticRow({required this.statistic});

  final HabitStatistic statistic;

  @override
  Widget build(BuildContext context) {
    final percentage = (statistic.completionRate * 100).round();
    return Semantics(
      label:
          '${statistic.name}, $percentage por ciento, '
          '${statistic.streak} días de racha, '
          '${statistic.skipped} omitidos',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statistic.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${statistic.streak} días de racha · ${statistic.skipped} omitidos',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$percentage%',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _InsufficientStatistics extends StatelessWidget {
  const _InsufficientStatistics();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.query_stats_outlined,
              size: 44,
              color: AppColors.primary,
            ),
            SizedBox(height: 12),
            Text('Aún no hay datos suficientes.', textAlign: TextAlign.center),
            SizedBox(height: 6),
            Text(
              'Prueba otro periodo o registra más días de tus hábitos.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final ProgressPeriod selected;
  final ValueChanged<ProgressPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ProgressPeriod>(
      segments: [
        for (final period in ProgressPeriod.values)
          ButtonSegment(value: period, label: Text(period.label)),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (values) => onSelected(values.first),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final percentage = (summary.completionRate * 100).round();
    final change = (summary.changeVsPrevious * 100).round();
    return Semantics(
      container: true,
      label:
          'Cumplimiento ${summary.period.label.toLowerCase()}, '
          '$percentage por ciento, '
          '${change >= 0 ? 'más' : 'menos'} ${change.abs()} por ciento '
          'frente al periodo anterior, '
          '${summary.completed} de ${summary.scheduled} completados',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cumplimiento ${summary.period.label.toLowerCase()}',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: AppColors.accent),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$percentage%',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${change >= 0 ? '+' : ''}$change% vs. periodo anterior',
                    textAlign: TextAlign.end,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: summary.completionRate.clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: AppColors.accent,
              backgroundColor: Colors.white24,
            ),
            const SizedBox(height: 10),
            Text(
              _dateRange(summary.from, summary.to),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeatmapCard extends StatelessWidget {
  const _HeatmapCard({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actividad del periodo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Cada celda representa el cumplimiento de un día.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: summary.days.length,
              itemBuilder: (context, index) {
                final day = summary.days[index];
                final percent = (day.completionRate * 100).round();
                return Semantics(
                  label: '${_shortDate(day.date)}: $percent% de cumplimiento',
                  child: Tooltip(
                    message: '${_shortDate(day.date)} · $percent%',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _heatColor(day.completionRate, day.scheduled),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Center(
                        child: Text(
                          '${day.date.day}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: day.completionRate >= 0.65
                                    ? Colors.white
                                    : AppColors.body,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.summary});

  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        icon: Icons.local_fire_department_outlined,
        value: '${summary.currentStreak} días',
        label: 'Racha actual',
      ),
      _MetricCard(
        icon: Icons.emoji_events_outlined,
        value: '${summary.longestStreak} días',
        label: 'Mejor racha',
      ),
      _MetricCard(
        icon: Icons.check_circle_outline,
        value: '${summary.completed}/${summary.scheduled}',
        label: 'Completados',
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 340 ? 1 : 3;
        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final scaleAdjustment = 1 + ((textScale - 1).clamp(0, 1) * 0.35);
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: (columns == 1 ? 2.6 : 0.82) / scaleAdjustment,
          children: cards,
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, $value',
      excludeSemantics: true,
      child: Card(
        child: SizedBox(
          height: 112,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyProgress extends StatelessWidget {
  const _EmptyProgress();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insights_outlined, size: 44, color: AppColors.primary),
            SizedBox(height: 12),
            Text(
              'Aún no hay datos para este periodo.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              'Registra el cumplimiento de tus hábitos para ver tu avance.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressError extends StatelessWidget {
  const _ProgressError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
      ),
    );
  }
}

Color _heatColor(double rate, int scheduled) {
  if (scheduled == 0) return AppColors.canvas;
  if (rate >= 0.85) return AppColors.primary;
  if (rate >= 0.5) return const Color(0xFF7FD7C7);
  if (rate > 0) return const Color(0xFFCDEFE8);
  return const Color(0xFFF1F5F4);
}

String _dateRange(DateTime from, DateTime to) {
  return '${_shortDate(from)} - ${_shortDate(to)}';
}

String _shortDate(DateTime date) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
