import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../../habits/domain/entities/habito.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../domain/entities/recordatorio.dart';
import '../providers/reminder_providers.dart';
import '../widgets/reminder_card.dart';
import '../widgets/reminder_form_sheet.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({required this.habitId, super.key});

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersListProvider(habitId));
    final habit = ref.watch(habitDetailProvider(habitId));
    final mutation = ref.watch(reminderControllerProvider(habitId));

    return Scaffold(
      appBar: AppBar(title: const Text('Recordatorios')),
      body: AppContent(
        child: reminders.when(
          data: (items) => _ReminderList(
            reminders: items,
            habit: habit.value,
            actionsEnabled: !mutation.isLoading,
            onAdd: () => _openForm(context, habit: habit.value),
            onEdit: (reminder) =>
                _openForm(context, habit: habit.value, reminder: reminder),
            onToggle: (reminder, active) =>
                _toggle(context, ref, reminder, active),
            onDelete: (reminder) => _confirmDelete(context, ref, reminder),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _LoadError(
            onRetry: () => ref.invalidate(remindersListProvider(habitId)),
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context, {
    required Habito? habit,
    Recordatorio? reminder,
  }) async {
    if (reminder == null && !canActivateReminders(habit)) {
      _showMessage(context, reminderEligibilityMessage);
      return;
    }

    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          ReminderFormSheet(habitId: habitId, reminder: reminder),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    Recordatorio reminder,
    bool active,
  ) async {
    final success = await ref
        .read(reminderControllerProvider(habitId).notifier)
        .toggle(reminder, active);
    if (!context.mounted || success) return;
    _showMessage(
      context,
      reminderErrorMessage(ref.read(reminderControllerProvider(habitId)).error),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Recordatorio reminder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar recordatorio?'),
        content: Text(
          'Se eliminará “${reminder.mensaje}”. Esta acción no se puede '
          'deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final success = await ref
        .read(reminderControllerProvider(habitId).notifier)
        .delete(reminder.id);
    if (!context.mounted || success) return;
    _showMessage(
      context,
      reminderErrorMessage(ref.read(reminderControllerProvider(habitId)).error),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ReminderList extends StatelessWidget {
  const _ReminderList({
    required this.reminders,
    required this.habit,
    required this.actionsEnabled,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final List<Recordatorio> reminders;
  final Habito? habit;
  final bool actionsEnabled;
  final VoidCallback onAdd;
  final ValueChanged<Recordatorio> onEdit;
  final void Function(Recordatorio reminder, bool active) onToggle;
  final ValueChanged<Recordatorio> onDelete;

  @override
  Widget build(BuildContext context) {
    final canCreate = canActivateReminders(habit);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _SummaryCard(reminders: reminders),
        const SizedBox(height: 20),
        const AppSectionLabel('Tus recordatorios'),
        const SizedBox(height: 10),
        if (!canCreate) ...[
          const _EligibilityNotice(),
          const SizedBox(height: 12),
        ],
        if (reminders.isEmpty)
          _EmptyState(onAdd: canCreate && actionsEnabled ? onAdd : null)
        else ...[
          for (final reminder in reminders) ...[
            ReminderCard(
              reminder: reminder,
              actionsEnabled: actionsEnabled,
              toggleEnabled: actionsEnabled && (reminder.activo || canCreate),
              onEdit: () => onEdit(reminder),
              onToggle: (active) => onToggle(reminder, active),
              onDelete: () => onDelete(reminder),
            ),
            const SizedBox(height: 12),
          ],
          _AddReminderAction(
            onPressed: canCreate && actionsEnabled ? onAdd : null,
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.reminders});

  final List<Recordatorio> reminders;

  @override
  Widget build(BuildContext context) {
    final activeCount = reminders.where((item) => item.activo).length;
    final programmedCopy = activeCount == 1
        ? '1 recordatorio programado'
        : '$activeCount recordatorios programados';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.accent,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notificaciones activas',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    programmedCopy,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFBCEFE6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.alarm_add_outlined,
              size: 42,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Aún no tienes recordatorios',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Añade uno para recibir un aviso en el momento que elijas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Añadir recordatorio'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddReminderAction extends StatelessWidget {
  const _AddReminderAction({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: enabled ? AppColors.primary : AppColors.border,
        radius: 16,
      ),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide.none,
          foregroundColor: enabled ? AppColors.primary : AppColors.muted,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Añadir recordatorio'),
      ),
    );
  }
}

class _EligibilityNotice extends StatelessWidget {
  const _EligibilityNotice();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: AppColors.warning),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Este hábito está pausado o completado. Puedes editar, '
                'desactivar o eliminar su configuración, pero no crear ni '
                'reactivar recordatorios.',
              ),
            ),
          ],
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
            const SizedBox(height: 14),
            const Text('No pudimos cargar tus recordatorios.'),
            const SizedBox(height: 14),
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final metric = path.computeMetrics().single;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    const dash = 7.0;
    const gap = 5.0;
    for (var distance = 0.0; distance < metric.length; distance += dash + gap) {
      canvas.drawPath(
        metric.extractPath(distance, math.min(distance + dash, metric.length)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color || radius != oldDelegate.radius;
  }
}
