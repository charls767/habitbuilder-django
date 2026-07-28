import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../domain/entities/frecuencia.dart';
import '../../domain/entities/habito.dart';
import '../providers/habit_providers.dart';

class HabitsListScreen extends ConsumerWidget {
  const HabitsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hábitos del día'),
        actions: [
          IconButton(
            onPressed: () => context.go(AppRoutes.profile),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Abrir perfil',
          ),
        ],
      ),
      body: habits.when(
        data: (items) => items.isEmpty
            ? _EmptyHabits(onCreate: () => context.push(AppRoutes.habitCreate))
            : RefreshIndicator(
                onRefresh: () async => ref.refresh(habitsListProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, index) =>
                      SizedBox(height: index == 0 ? 16 : 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _ListHeader(count: items.length);
                    }
                    final habit = items[index - 1];
                    return _HabitCard(
                      habit: habit,
                      onEdit: () => context.push(AppRoutes.habitEdit(habit.id)),
                    );
                  },
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            _LoadError(onRetry: () => ref.invalidate(habitsListProvider)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.habitCreate),
        tooltip: 'Crear hábito',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${now.day} de ${months[now.month - 1]}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          count == 1 ? '1 hábito configurado' : '$count hábitos configurados',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit, required this.onEdit});

  final Habito habit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPaused = habit.estado == HabitoEstado.pausado;
    final isCompleted = habit.estado == HabitoEstado.completado;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? colors.tertiaryContainer
                      : colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.check
                      : isPaused
                      ? Icons.pause
                      : Icons.checklist,
                  color: isCompleted
                      ? colors.onTertiaryContainer
                      : colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _frequencyLabel(habit.frecuencia),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (habit.estado != HabitoEstado.activo) ...[
                      const SizedBox(height: 4),
                      Text(
                        isPaused ? 'Pausado' : 'Completado',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: isPaused ? colors.error : colors.tertiary,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Editar ${habit.nombre}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _frequencyLabel(Frecuencia frequency) {
  return switch (frequency) {
    FrecuenciaDiaria() => 'Todos los días',
    FrecuenciaDiasSemana(:final diasSemana) =>
      'Días: ${diasSemana.map(_weekday).join(', ')}',
    FrecuenciaVecesPeriodo(:final veces, :final periodo) =>
      '$veces veces por ${periodo == PeriodoFrecuencia.semana ? 'semana' : 'mes'}',
  };
}

String _weekday(int day) {
  const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  return labels[day - 1];
}

class _EmptyHabits extends StatelessWidget {
  const _EmptyHabits({required this.onCreate});

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
              const Icon(Icons.checklist, size: 56),
              const SizedBox(height: 16),
              Text(
                'Tu lista está lista para empezar',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Crea un hábito y define cuándo quieres practicarlo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Crear hábito'),
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
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 16),
            const Text('No pudimos cargar tus hábitos.'),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
