import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../domain/entities/meta.dart';
import '../providers/goal_providers.dart';

class GoalsListScreen extends ConsumerWidget {
  const GoalsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis metas'),
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.habits),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          tooltip: 'Volver a hábitos',
        ),
      ),
      body: goals.when(
        data: (items) => items.isEmpty
            ? _EmptyGoals(onCreate: () => context.push(AppRoutes.goalCreate))
            : AppContent(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () => ref.refresh(goalsListProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final goal = items[index];
                      return _GoalCard(
                        goal: goal,
                        onTap: () =>
                            context.push(AppRoutes.goalDetail(goal.id)),
                      );
                    },
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            _LoadError(onRetry: () => ref.invalidate(goalsListProvider)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.goalCreate),
        tooltip: 'Crear meta',
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const AppDestinationBar(selectedIndex: 2),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final Meta goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _stateBackground(goal.estado),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _stateIcon(goal.estado),
                      color: _stateColor(goal.estado),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          goal.habitoIds.length == 1
                              ? 'Meta · 1 hábito vinculado'
                              : 'Meta · ${goal.habitoIds.length} hábitos vinculados',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  AppStatusPill(
                    label: goalStateLabel(goal.estado),
                    foreground: _stateColor(goal.estado),
                    background: _stateBackground(goal.estado),
                  ),
                ],
              ),
              if (goal.fechaObjetivo case final date?) ...[
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 17,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Fecha objetivo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatGoalDate(date),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.flag_outlined,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Define tu próxima meta',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Agrupa hábitos bajo un resultado que quieras alcanzar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Crear meta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 16),
          const Text('No pudimos cargar tus metas.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

String goalStateLabel(MetaEstado state) {
  return switch (state) {
    MetaEstado.enProgreso => 'En curso',
    MetaEstado.lograda => 'Alcanzada',
    MetaEstado.pausada => 'Pausada',
    MetaEstado.cancelada => 'Cancelada',
  };
}

String formatGoalDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

IconData _stateIcon(MetaEstado state) {
  return switch (state) {
    MetaEstado.enProgreso => Icons.flag_outlined,
    MetaEstado.lograda => Icons.task_alt,
    MetaEstado.pausada => Icons.pause_circle_outline,
    MetaEstado.cancelada => Icons.cancel_outlined,
  };
}

Color _stateColor(MetaEstado state) {
  return switch (state) {
    MetaEstado.enProgreso => AppColors.primary,
    MetaEstado.lograda => AppColors.success,
    MetaEstado.pausada => const Color(0xFFB45309),
    MetaEstado.cancelada => AppColors.danger,
  };
}

Color _stateBackground(MetaEstado state) {
  return switch (state) {
    MetaEstado.enProgreso => AppColors.mint,
    MetaEstado.lograda => const Color(0xFFDCFCE7),
    MetaEstado.pausada => const Color(0xFFFFF3D6),
    MetaEstado.cancelada => const Color(0xFFFEE2E2),
  };
}
