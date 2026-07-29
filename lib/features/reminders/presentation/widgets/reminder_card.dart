import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/recordatorio.dart';

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    required this.reminder,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.toggleEnabled,
    required this.actionsEnabled,
    super.key,
  });

  final Recordatorio reminder;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final bool toggleEnabled;
  final bool actionsEnabled;

  @override
  Widget build(BuildContext context) {
    final status = reminder.activo ? 'activo' : 'inactivo';

    return Semantics(
      container: true,
      label: 'Recordatorio ${reminder.mensaje} a las ${reminder.hora}, $status',
      child: Opacity(
        opacity: reminder.activo ? 1 : 0.64,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: actionsEnabled ? onEdit : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.hora.toString(),
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              reminder.mensaje,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Semantics(
                        label: reminder.activo
                            ? 'Desactivar ${reminder.mensaje}'
                            : 'Activar ${reminder.mensaje}',
                        child: Switch(
                          key: ValueKey('reminder-toggle-${reminder.id}'),
                          value: reminder.activo,
                          onChanged: toggleEnabled ? onToggle : null,
                        ),
                      ),
                      PopupMenuButton<_ReminderMenuAction>(
                        enabled: actionsEnabled,
                        tooltip: 'Más acciones para ${reminder.mensaje}',
                        onSelected: (action) {
                          switch (action) {
                            case _ReminderMenuAction.edit:
                              onEdit();
                            case _ReminderMenuAction.delete:
                              onDelete();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _ReminderMenuAction.edit,
                            child: ListTile(
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Editar'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: _ReminderMenuAction.delete,
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
                  if (reminder.diasSemana.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (reminder.diasSemana.length == 7)
                          const _DayChip('Todos los días')
                        else
                          for (final day in reminder.diasSemana)
                            _DayChip(_weekday(day)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ReminderMenuAction { edit, delete }

class _DayChip extends StatelessWidget {
  const _DayChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _weekday(int day) {
  const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  return labels[day - 1];
}
