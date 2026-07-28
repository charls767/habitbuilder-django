import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_routes.dart';
import '../../../habits/domain/entities/habito.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../domain/entities/meta.dart';
import '../providers/goal_providers.dart';
import 'goals_list_screen.dart';

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({required this.goalId, super.key});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(goalDetailProvider(goalId))
        .when(
          data: (goal) => _GoalDetailBody(goal: goal),
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Detalle de meta')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Scaffold(
            appBar: AppBar(title: const Text('Detalle de meta')),
            body: Center(
              child: OutlinedButton.icon(
                onPressed: () => ref.invalidate(goalDetailProvider(goalId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
          ),
        );
  }
}

class _GoalDetailBody extends ConsumerWidget {
  const _GoalDetailBody({required this.goal});

  final Meta goal;

  Future<void> _manageHabits(
    BuildContext context,
    WidgetRef ref,
    List<Habito> habits,
  ) async {
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _HabitSelector(goal: goal, habits: habits),
    );
    if (selected == null || !context.mounted) return;

    final success = await ref
        .read(goalControllerProvider.notifier)
        .updateHabitLinks(
          goalId: goal.id,
          previousHabitIds: goal.habitoIds,
          selectedHabitIds: selected,
        );
    if (!context.mounted) return;
    final error = ref.read(goalControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Hábitos de la meta actualizados.'
              : error is ApiException
              ? error.message
              : 'No se pudieron actualizar los hábitos.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsState = ref.watch(habitsListProvider);
    final allHabits = habitsState.value ?? const <Habito>[];
    final linked = allHabits
        .where((habit) => goal.habitoIds.contains(habit.id))
        .toList();
    final controller = ref.watch(goalControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de meta'),
        actions: [
          IconButton(
            onPressed: () => context.push(AppRoutes.goalEdit(goal.id)),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar meta',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(goal.nombre, style: Theme.of(context).textTheme.headlineSmall),
          if (goal.descripcion case final description?) ...[
            const SizedBox(height: 10),
            Text(description),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _DetailValue(
                icon: Icons.info_outline,
                label: 'Estado',
                value: goalStateLabel(goal.estado),
              ),
              if (goal.fechaObjetivo case final date?)
                _DetailValue(
                  icon: Icons.event_outlined,
                  label: 'Fecha objetivo',
                  value: formatGoalDate(date),
                ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Hábitos vinculados',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: controller.isLoading || habitsState.isLoading
                    ? null
                    : () => _manageHabits(context, ref, allHabits),
                icon: const Icon(Icons.link),
                label: const Text('Gestionar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (habitsState.hasError)
            _HabitLoadError(onRetry: () => ref.invalidate(habitsListProvider))
          else if (habitsState.isLoading)
            const Center(child: CircularProgressIndicator())
          else if (linked.isEmpty)
            const _EmptyLinkedHabits()
          else
            ...linked.map(
              (habit) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.checklist_outlined),
                title: Text(habit.nombre),
                subtitle: Text(_habitStateLabel(habit.estado)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.habitEdit(habit.id)),
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitSelector extends StatefulWidget {
  const _HabitSelector({required this.goal, required this.habits});

  final Meta goal;
  final List<Habito> habits;

  @override
  State<_HabitSelector> createState() => _HabitSelectorState();
}

class _HabitSelectorState extends State<_HabitSelector> {
  late final Set<String> _selected = widget.goal.habitoIds.toSet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gestionar hábitos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: widget.habits.isEmpty
                  ? const Center(child: Text('Aún no tienes hábitos.'))
                  : ListView.builder(
                      itemCount: widget.habits.length,
                      itemBuilder: (context, index) {
                        final habit = widget.habits[index];
                        final belongsElsewhere =
                            habit.metaId != null &&
                            habit.metaId != widget.goal.id;
                        return CheckboxListTile(
                          value: _selected.contains(habit.id),
                          onChanged: (checked) => setState(() {
                            if (checked ?? false) {
                              _selected.add(habit.id);
                            } else {
                              _selected.remove(habit.id);
                            }
                          }),
                          title: Text(habit.nombre),
                          subtitle: belongsElsewhere
                              ? const Text(
                                  'Vinculado a otra meta; se reasignará.',
                                )
                              : null,
                          secondary: const Icon(Icons.checklist_outlined),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _selected),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Guardar vínculos'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailValue extends StatelessWidget {
  const _DetailValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value),
          ],
        ),
      ],
    );
  }
}

class _EmptyLinkedHabits extends StatelessWidget {
  const _EmptyLinkedHabits();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.link_off, size: 40),
          SizedBox(height: 10),
          Text('Esta meta todavía no tiene hábitos vinculados.'),
        ],
      ),
    );
  }
}

class _HabitLoadError extends StatelessWidget {
  const _HabitLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar hábitos'),
      ),
    );
  }
}

String _habitStateLabel(HabitoEstado state) {
  return switch (state) {
    HabitoEstado.activo => 'Activo',
    HabitoEstado.pausado => 'Pausado',
    HabitoEstado.completado => 'Completado',
  };
}
