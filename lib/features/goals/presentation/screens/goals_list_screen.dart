import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../domain/entities/meta.dart';
import '../providers/goal_providers.dart';

class GoalsListScreen extends ConsumerWidget {
  const GoalsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas'),
        actions: [
          IconButton(
            onPressed: () => context.go(AppRoutes.habits),
            icon: const Icon(Icons.checklist_outlined),
            tooltip: 'Ir a hábitos',
          ),
          IconButton(
            onPressed: () => context.go(AppRoutes.profile),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Ir al perfil',
          ),
        ],
      ),
      body: goals.when(
        data: (items) => items.isEmpty
            ? _EmptyGoals(onCreate: () => context.push(AppRoutes.goalCreate))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(goalsListProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final goal = items[index];
                    return _GoalCard(
                      goal: goal,
                      onTap: () => context.push(AppRoutes.goalDetail(goal.id)),
                    );
                  },
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
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});

  final Meta goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _stateIcon(goal.estado),
                  color: colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _InlineLabel(
                          icon: _stateIcon(goal.estado),
                          text: goalStateLabel(goal.estado),
                        ),
                        if (goal.fechaObjetivo case final date?)
                          _InlineLabel(
                            icon: Icons.event_outlined,
                            text: formatGoalDate(date),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineLabel extends StatelessWidget {
  const _InlineLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
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
              const Icon(Icons.flag_outlined, size: 56),
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
