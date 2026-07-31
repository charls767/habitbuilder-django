import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../domain/entities/frecuencia.dart';
import '../../domain/entities/habito.dart';
import '../providers/habit_providers.dart';

class HabitsListScreen extends ConsumerWidget {
  const HabitsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsListProvider);
    final controllerState = ref.watch(habitControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hábitos del día'),
        leading: const Icon(
          Icons.local_fire_department_rounded,
          color: AppColors.primary,
        ),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.community),
            tooltip: 'Comunidad e inspiración',
            icon: const Icon(Icons.forum_outlined),
          ),
        ],
      ),
      body: habits.when(
        data: (items) => items.isEmpty
            ? _EmptyHabits(onCreate: () => context.push(AppRoutes.habitCreate))
            : AppContent(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async => ref.refresh(habitsListProvider.future),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, index) =>
                        SizedBox(height: index == 0 ? 18 : 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ListHeader(count: items.length);
                      }
                      final habit = items[index - 1];
                      return _HabitCard(
                        habit: habit,
                        onEdit: () =>
                            context.push(AppRoutes.habitEdit(habit.id)),
                        onReminders: () =>
                            context.push(AppRoutes.habitReminders(habit.id)),
                        actionsEnabled: !controllerState.isLoading,
                        onAction: (action) =>
                            _confirmAndRun(context, ref, habit, action),
                      );
                    },
                  ),
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
      bottomNavigationBar: const AppDestinationBar(selectedIndex: 0),
    );
  }

  Future<void> _confirmAndRun(
    BuildContext context,
    WidgetRef ref,
    Habito habit,
    _HabitAction action,
  ) async {
    final copy = _confirmationCopy(action, habit.nombre);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.title),
        content: Text(copy.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: action == _HabitAction.delete
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(
                      dialogContext,
                    ).colorScheme.onError,
                  )
                : null,
            child: Text(copy.confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final controller = ref.read(habitControllerProvider.notifier);
    final success = switch (action) {
      _HabitAction.pause => await controller.pauseHabit(habit.id),
      _HabitAction.resume => await controller.resumeHabit(habit.id),
      _HabitAction.complete => await controller.completeHabit(habit.id),
      _HabitAction.delete => await controller.deleteHabit(habit.id),
    };
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (success) {
      messenger.showSnackBar(SnackBar(content: Text(copy.successMessage)));
      return;
    }
    final error = ref.read(habitControllerProvider).error;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error is ApiException
              ? error.message
              : 'No pudimos completar la acción. Intenta de nuevo.',
        ),
        action: SnackBarAction(
          label: 'Reintentar',
          onPressed: () => _confirmAndRun(context, ref, habit, action),
        ),
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
    const weekdays = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
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
          '${weekdays[now.weekday - 1]}, ${now.day} de ${months[now.month - 1]}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          count == 1 ? '1 hábito configurado' : '$count hábitos configurados',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.onEdit,
    required this.onReminders,
    required this.actionsEnabled,
    required this.onAction,
  });

  final Habito habit;
  final VoidCallback onEdit;
  final VoidCallback onReminders;
  final bool actionsEnabled;
  final ValueChanged<_HabitAction> onAction;

  @override
  Widget build(BuildContext context) {
    final isPaused = habit.estado == HabitoEstado.pausado;
    final isCompleted = habit.estado == HabitoEstado.completado;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? const Color(0xFFDCFCE7)
                      : isPaused
                      ? const Color(0xFFFFF3D6)
                      : AppColors.mint,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.task_alt_rounded
                      : isPaused
                      ? Icons.pause_rounded
                      : Icons.checklist_rounded,
                  color: isCompleted
                      ? AppColors.success
                      : isPaused
                      ? AppColors.warning
                      : AppColors.primary,
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                    if (habit.estado != HabitoEstado.activo) ...[
                      const SizedBox(height: 7),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AppStatusPill(
                          label: isPaused ? 'Pausado' : 'Completado',
                          foreground: isPaused
                              ? const Color(0xFFB45309)
                              : AppColors.success,
                          background: isPaused
                              ? const Color(0xFFFFF3D6)
                              : const Color(0xFFDCFCE7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onReminders,
                tooltip: 'Recordatorios para ${habit.nombre}',
                icon: const Icon(Icons.alarm_outlined),
              ),
              PopupMenuButton<_HabitAction>(
                enabled: actionsEnabled,
                tooltip: 'Más acciones para ${habit.nombre}',
                onSelected: onAction,
                itemBuilder: (context) => [
                  if (habit.estado == HabitoEstado.activo)
                    const PopupMenuItem(
                      value: _HabitAction.pause,
                      child: ListTile(
                        leading: Icon(Icons.pause_outlined),
                        title: Text('Pausar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (habit.estado == HabitoEstado.pausado)
                    const PopupMenuItem(
                      value: _HabitAction.resume,
                      child: ListTile(
                        leading: Icon(Icons.play_arrow_outlined),
                        title: Text('Reanudar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  if (habit.estado != HabitoEstado.completado)
                    const PopupMenuItem(
                      value: _HabitAction.complete,
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('Completar'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  const PopupMenuItem(
                    value: _HabitAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Eliminar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _HabitAction { pause, resume, complete, delete }

({String title, String message, String confirmLabel, String successMessage})
_confirmationCopy(_HabitAction action, String habitName) {
  return switch (action) {
    _HabitAction.pause => (
      title: '¿Pausar hábito?',
      message:
          '"$habitName" dejará de aparecer como activo. '
          'Podrás reanudarlo cuando quieras.',
      confirmLabel: 'Pausar',
      successMessage: 'Hábito pausado.',
    ),
    _HabitAction.resume => (
      title: '¿Reanudar hábito?',
      message: '"$habitName" volverá a aparecer como activo.',
      confirmLabel: 'Reanudar',
      successMessage: 'Hábito reanudado.',
    ),
    _HabitAction.complete => (
      title: '¿Completar hábito?',
      message:
          '"$habitName" quedará marcado como completado. '
          'Esta acción representa que alcanzaste el objetivo del hábito.',
      confirmLabel: 'Completar',
      successMessage: 'Hábito completado.',
    ),
    _HabitAction.delete => (
      title: '¿Eliminar hábito?',
      message:
          '"$habitName" se quitará de tu lista. Sus registros históricos '
          'se conservarán cuando sean necesarios para reportes relacionados.',
      confirmLabel: 'Eliminar',
      successMessage: 'Hábito eliminado.',
    ),
  };
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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.checklist_rounded,
                  size: 34,
                  color: AppColors.primary,
                ),
              ),
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
