import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../../habits/domain/entities/habito.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../domain/entities/recordatorio.dart';
import '../../domain/entities/reminder_time.dart';
import '../providers/reminder_providers.dart';

class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({required this.habitId, super.key});

  final String habitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(remindersListProvider(habitId));
    final habit = ref.watch(habitDetailProvider(habitId));

    return Scaffold(
      appBar: AppBar(title: const Text('Recordatorios')),
      body: AppContent(
        child: reminders.when(
          data: (items) => _ReminderList(
            reminders: items,
            habit: habit.value,
            onAdd: () => _openCreate(context, ref, habit.value),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _LoadError(
            onRetry: () => ref.invalidate(remindersListProvider(habitId)),
          ),
        ),
      ),
    );
  }

  Future<void> _openCreate(
    BuildContext context,
    WidgetRef ref,
    Habito? habit,
  ) async {
    if (habit?.estado != HabitoEstado.activo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Los hábitos pausados o completados no pueden crear ni reactivar '
            'recordatorios.',
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ReminderCreateSheet(habitId: habitId),
    );
  }
}

class _ReminderList extends StatelessWidget {
  const _ReminderList({
    required this.reminders,
    required this.habit,
    required this.onAdd,
  });

  final List<Recordatorio> reminders;
  final Habito? habit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final canCreate = habit?.estado == HabitoEstado.activo;

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
          _EmptyState(onAdd: canCreate ? onAdd : null)
        else ...[
          for (final reminder in reminders) ...[
            _ReminderPreview(reminder: reminder),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: canCreate ? onAdd : null,
            icon: const Icon(Icons.add_alarm_outlined),
            label: const Text('Añadir recordatorio'),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$activeCount activos',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  Text(
                    reminders.isEmpty
                        ? 'Configura cuándo quieres recibir un aviso.'
                        : '${reminders.length} configurados para este hábito.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
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

class _ReminderPreview extends StatelessWidget {
  const _ReminderPreview({required this.reminder});

  final Recordatorio reminder;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reminder.hora.toString(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(reminder.mensaje),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final day in reminder.diasSemana)
                  Chip(label: Text(_weekday(day))),
              ],
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
                'Este hábito está pausado o completado. Puedes conservar su '
                'configuración, pero no crear ni reactivar recordatorios.',
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

class _ReminderCreateSheet extends ConsumerStatefulWidget {
  const _ReminderCreateSheet({required this.habitId});

  final String habitId;

  @override
  ConsumerState<_ReminderCreateSheet> createState() =>
      _ReminderCreateSheetState();
}

class _ReminderCreateSheetState extends ConsumerState<_ReminderCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _timeController = TextEditingController();
  final _selectedDays = <int>{};
  String? _errorMessage;
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderControllerProvider(widget.habitId));
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Añadir recordatorio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(labelText: 'Mensaje'),
              textInputAction: TextInputAction.next,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Escribe un mensaje'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _timeController,
              decoration: const InputDecoration(labelText: 'Hora (HH:mm)'),
              keyboardType: TextInputType.datetime,
              validator: (value) {
                try {
                  ReminderTime.parse(value ?? '');
                  return null;
                } on FormatException {
                  return 'Usa una hora válida en formato HH:mm';
                }
              },
            ),
            const SizedBox(height: 16),
            const AppSectionLabel('Días'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(_weekdayInitial(day)),
                    selected: _selectedDays.contains(day),
                    onSelected: _submitting
                        ? null
                        : (selected) {
                            setState(() {
                              if (selected) {
                                _selectedDays.add(day);
                              } else {
                                _selectedDays.remove(day);
                              }
                            });
                          },
                  ),
              ],
            ),
            if (_selectedDays.isEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Selecciona al menos un día',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            if (_errorMessage case final message?) ...[
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar recordatorio'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _selectedDays.isEmpty) {
      setState(() {});
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final success = await ref
        .read(reminderControllerProvider(widget.habitId).notifier)
        .create(
          ReminderDraft(
            mensaje: _messageController.text,
            hora: ReminderTime.parse(_timeController.text),
            diasSemana: _selectedDays.toList(),
            activo: true,
          ),
        );
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      return;
    }

    final error = ref.read(reminderControllerProvider(widget.habitId)).error;
    setState(() {
      _submitting = false;
      _errorMessage = switch (error) {
        ApiException(:final message) => message,
        ReminderEligibilityException(:final message) => message,
        _ => 'No pudimos guardar el recordatorio. Intenta de nuevo.',
      };
    });
  }
}

String _weekday(int day) {
  const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  return labels[day - 1];
}

String _weekdayInitial(int day) {
  const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  return labels[day - 1];
}
