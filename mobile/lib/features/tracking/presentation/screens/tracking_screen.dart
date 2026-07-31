import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../../habits/domain/entities/habito.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../domain/entities/registro_habito.dart';
import '../providers/tracking_providers.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cumplimiento diario'),
        actions: [
          IconButton(
            onPressed: _pickDate,
            tooltip: 'Elegir fecha',
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
      body: habits.when(
        data: (items) {
          final trackable = items
              .where((habit) => habit.estado == HabitoEstado.activo)
              .toList(growable: false);
          return AppContent(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _refresh(trackable),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _DateHeader(
                      date: _selectedDate,
                      canGoForward: !_isToday(_selectedDate),
                      onPrevious: () => _moveDate(-1),
                      onNext: () => _moveDate(1),
                    ),
                  ),
                  if (trackable.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyTracking(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
                      sliver: SliverList.separated(
                        itemCount: trackable.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _HabitTrackingCard(
                          habit: trackable[index],
                          date: _selectedDate,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: OutlinedButton.icon(
            onPressed: () => ref.invalidate(habitsListProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ),
      ),
      bottomNavigationBar: const AppDestinationBar(selectedIndex: 1),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected == null) return;
    setState(() {
      _selectedDate = DateTime(selected.year, selected.month, selected.day);
    });
  }

  void _moveDate(int days) {
    final next = _selectedDate.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _selectedDate = next);
  }

  Future<void> _refresh(List<Habito> habits) async {
    await ref.read(trackingSyncRequestProvider)();
    final refresh = ref.read(trackingRefreshRequestProvider);
    for (final habit in habits) {
      await refresh(habit.id, from: _selectedDate, to: _selectedDate);
      ref.invalidate(trackingLogProvider(habit.id, _selectedDate));
    }
    ref.invalidate(habitsListProvider);
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime date;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            tooltip: 'Día anterior',
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Semantics(
              header: true,
              label:
                  '${_isToday(date) ? 'Hoy' : _weekday(date.weekday)}, '
                  '${_friendlyDate(date)}',
              excludeSemantics: true,
              child: Column(
                children: [
                  Text(
                    _isToday(date) ? 'Hoy' : _weekday(date.weekday),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _friendlyDate(date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: canGoForward ? onNext : null,
            tooltip: 'Día siguiente',
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _HabitTrackingCard extends ConsumerWidget {
  const _HabitTrackingCard({required this.habit, required this.date});

  final Habito habit;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = ref.watch(trackingLogProvider(habit.id, date));
    final controller = ref.watch(trackingControllerProvider(habit.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              container: true,
              header: true,
              label: 'Hábito ${habit.nombre}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      habit.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (controller.isLoading)
                    const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        semanticsLabel: 'Guardando registro',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            record.when(
              data: (value) => Column(
                children: [
                  _StatusSelector(
                    habitName: habit.nombre,
                    selected: value?.estado,
                    enabled: !controller.isLoading,
                    onSelected: (status) =>
                        _save(context, ref, status, value?.nota),
                  ),
                  if (value != null &&
                      value.sincronizacion !=
                          EstadoSincronizacion.sincronizado) ...[
                    const SizedBox(height: 8),
                    _SyncStatus(
                      status: value.sincronizacion,
                      onRetry:
                          value.sincronizacion == EstadoSincronizacion.conflicto
                          ? () => _save(context, ref, value.estado, value.nota)
                          : null,
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          value?.nota?.isNotEmpty == true
                              ? value!.nota!
                              : 'Sin nota',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      IconButton(
                        onPressed: controller.isLoading
                            ? null
                            : () => _editNote(context, ref, value),
                        tooltip: value == null
                            ? 'Agregar nota para ${habit.nombre}'
                            : 'Editar nota para ${habit.nombre}',
                        icon: const Icon(Icons.edit_note_outlined),
                      ),
                    ],
                  ),
                ],
              ),
              loading: () => const LinearProgressIndicator(
                semanticsLabel: 'Cargando registro del hábito',
              ),
              error: (_, _) => Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      ref.invalidate(trackingLogProvider(habit.id, date)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar carga'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    RegistroHabito? record,
  ) async {
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona primero un estado.')),
      );
      return;
    }

    var editedNote = record.nota ?? '';
    final note = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nota del día'),
        content: TextFormField(
          initialValue: editedNote,
          autofocus: true,
          maxLength: 240,
          maxLines: 4,
          onChanged: (value) => editedNote = value,
          decoration: const InputDecoration(
            hintText: '¿Cómo te fue con este hábito?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, editedNote),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (note == null || !context.mounted) return;
    await _save(context, ref, record.estado, note);
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    EstadoRegistro status,
    String? note,
  ) async {
    final success = await ref
        .read(trackingControllerProvider(habit.id).notifier)
        .save(date: date, status: status, note: note);
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Guardado en este dispositivo.')),
      );
      return;
    }
    final error = ref.read(trackingControllerProvider(habit.id)).error;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error is ApiException
              ? error.message
              : 'No pudimos guardar el cumplimiento.',
        ),
      ),
    );
  }
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.status, this.onRetry});

  final EstadoSincronizacion status;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final conflict = status == EstadoSincronizacion.conflicto;
    final color = conflict
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final label = conflict
        ? 'Conflicto de sincronización'
        : 'Pendiente de sincronizar';
    return Semantics(
      liveRegion: true,
      label: label,
      child: Row(
        children: [
          Icon(
            conflict
                ? Icons.sync_problem_outlined
                : Icons.cloud_upload_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Reintentar'),
            ),
        ],
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({
    required this.habitName,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final String habitName;
  final EstadoRegistro? selected;
  final bool enabled;
  final ValueChanged<EstadoRegistro> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Estado de $habitName',
      explicitChildNodes: true,
      child: SegmentedButton<EstadoRegistro>(
        segments: const [
          ButtonSegment(
            value: EstadoRegistro.completado,
            icon: Icon(Icons.check_rounded),
            label: Text('Hecho'),
          ),
          ButtonSegment(
            value: EstadoRegistro.parcial,
            icon: Icon(Icons.timelapse_rounded),
            label: Text('Parcial'),
          ),
          ButtonSegment(
            value: EstadoRegistro.omitido,
            icon: Icon(Icons.remove_rounded),
            label: Text('Omitido'),
          ),
        ],
        selected: selected == null ? const {} : {selected!},
        emptySelectionAllowed: true,
        showSelectedIcon: false,
        onSelectionChanged: enabled
            ? (values) {
                if (values.isNotEmpty) onSelected(values.first);
              }
            : null,
      ),
    );
  }
}

class _EmptyTracking extends StatelessWidget {
  const _EmptyTracking();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'No tienes hábitos activos para registrar en esta fecha.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

String _weekday(int day) {
  const labels = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  return labels[day - 1];
}

String _friendlyDate(DateTime date) {
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
  return '${date.day} de ${months[date.month - 1]} de ${date.year}';
}
