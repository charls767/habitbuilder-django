import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../domain/entities/recordatorio.dart';
import '../../domain/entities/reminder_time.dart';
import '../providers/reminder_providers.dart';

class ReminderFormSheet extends ConsumerStatefulWidget {
  const ReminderFormSheet({required this.habitId, super.key, this.reminder});

  final String habitId;
  final Recordatorio? reminder;

  @override
  ConsumerState<ReminderFormSheet> createState() => _ReminderFormSheetState();
}

class _ReminderFormSheetState extends ConsumerState<ReminderFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _messageController;
  late final TextEditingController _timeController;
  late final Set<int> _selectedDays;
  String? _errorMessage;
  bool _submitting = false;
  bool _showDayError = false;

  @override
  void initState() {
    super.initState();
    final reminder = widget.reminder;
    _messageController = TextEditingController(text: reminder?.mensaje);
    _timeController = TextEditingController(text: reminder?.hora.toString());
    _selectedDays = {...?reminder?.diasSemana};
  }

  @override
  void dispose() {
    _messageController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderControllerProvider(widget.habitId));
    final editing = widget.reminder != null;
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
              editing ? 'Editar recordatorio' : 'Añadir recordatorio',
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
                              _showDayError = false;
                            });
                          },
                  ),
              ],
            ),
            if (_showDayError && _selectedDays.isEmpty) ...[
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
              key: const ValueKey('reminder-form-submit'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(editing ? 'Guardar cambios' : 'Guardar recordatorio'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _selectedDays.isEmpty) {
      setState(() => _showDayError = true);
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final controller = ref.read(
      reminderControllerProvider(widget.habitId).notifier,
    );
    final draft = ReminderDraft(
      mensaje: _messageController.text,
      hora: ReminderTime.parse(_timeController.text),
      diasSemana: _selectedDays.toList(),
      activo: widget.reminder?.activo ?? true,
    );
    final reminder = widget.reminder;
    final success = reminder == null
        ? await controller.create(draft)
        : await controller.updateReminder(reminder: reminder, draft: draft);
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    final error = ref.read(reminderControllerProvider(widget.habitId)).error;
    setState(() {
      _submitting = false;
      _errorMessage = reminderErrorMessage(error);
    });
  }
}

String reminderErrorMessage(Object? error) {
  return switch (error) {
    ApiException(:final message) => message,
    ReminderEligibilityException(:final message) => message,
    _ => 'No pudimos guardar el recordatorio. Intenta de nuevo.',
  };
}

String _weekdayInitial(int day) {
  const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  return labels[day - 1];
}
