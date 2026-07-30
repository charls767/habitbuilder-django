import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../domain/entities/progress_summary.dart';
import '../providers/progress_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(selectedProgressPeriodProvider);
    final summary = ref.watch(progressSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tu progreso')),
      body: AppContent(
        child: RefreshIndicator(
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
        ),
      ),
      bottomNavigationBar: const AppDestinationBar(selectedIndex: 3),
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
    return Container(
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
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
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: columns == 1 ? 2.6 : 0.82,
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
    return Card(
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
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
              ),
            ],
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
