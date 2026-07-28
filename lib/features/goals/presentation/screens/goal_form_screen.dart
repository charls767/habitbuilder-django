import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../habits/domain/entities/habito.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../domain/entities/meta.dart';
import '../providers/goal_providers.dart';
import 'goals_list_screen.dart';

class GoalFormScreen extends ConsumerStatefulWidget {
  const GoalFormScreen({super.key, this.goalId});

  final String? goalId;

  bool get isEditing => goalId != null;

  @override
  ConsumerState<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends ConsumerState<GoalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final Set<String> _selectedHabitIds = {};

  String? _hydratedGoalId;
  DateTime? _targetDate;
  MetaEstado _state = MetaEstado.enProgreso;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _hydrate(Meta goal) {
    if (_hydratedGoalId == goal.id) return;
    _hydratedGoalId = goal.id;
    _nameController.text = goal.nombre;
    _descriptionController.text = goal.descripcion ?? '';
    _setDate(goal.fechaObjetivo);
    _state = goal.estado;
    _selectedHabitIds
      ..clear()
      ..addAll(goal.habitoIds);
  }

  void _setDate(DateTime? value) {
    _targetDate = value == null
        ? null
        : DateTime(value.year, value.month, value.day);
    _dateController.text = _targetDate == null
        ? ''
        : formatGoalDate(_targetDate!);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 3650)),
      helpText: 'Fecha objetivo',
    );
    if (selected != null) {
      setState(() => _setDate(selected));
    }
  }

  Future<void> _save(Meta? original) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final description = _descriptionController.text.trim();
    final controller = ref.read(goalControllerProvider.notifier);
    final success = widget.isEditing
        ? await controller.updateGoal(
            goalId: widget.goalId!,
            nombre: _nameController.text.trim(),
            descripcion: description.isEmpty ? null : description,
            fechaObjetivo: _targetDate,
            estado: _state,
            previousHabitIds: original!.habitoIds,
            selectedHabitIds: _selectedHabitIds,
          )
        : await controller.createGoal(
            nombre: _nameController.text.trim(),
            descripcion: description.isEmpty ? null : description,
            fechaObjetivo: _targetDate,
            habitoIds: _selectedHabitIds.toList()..sort(),
          );

    if (!mounted) return;
    if (success) {
      await Navigator.of(context).maybePop();
      return;
    }
    final error = ref.read(goalControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is ApiException
              ? error.message
              : 'No se pudo guardar la meta. Revisa tu conexión.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return _buildForm(null);
    }
    return ref
        .watch(goalDetailProvider(widget.goalId!))
        .when(
          data: (goal) {
            _hydrate(goal);
            return _buildForm(goal);
          },
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Editar meta')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Scaffold(
            appBar: AppBar(title: const Text('Editar meta')),
            body: Center(
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(goalDetailProvider(widget.goalId!)),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
          ),
        );
  }

  Widget _buildForm(Meta? original) {
    final controllerState = ref.watch(goalControllerProvider);
    final habitsState = ref.watch(habitsListProvider);
    final habits = habitsState.value ?? const <Habito>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar meta' : 'Nueva meta'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const _SectionHeading(
              icon: Icons.flag_outlined,
              title: 'Información',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameController,
              autofocus: !widget.isEditing,
              maxLength: 120,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Dormir mejor',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Escribe un nombre para la meta'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                hintText: 'Opcional',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dateController,
              readOnly: true,
              onTap: _pickDate,
              decoration: InputDecoration(
                labelText: 'Fecha objetivo',
                hintText: 'Opcional',
                prefixIcon: const Icon(Icons.event_outlined),
                suffixIcon: _targetDate == null
                    ? IconButton(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        tooltip: 'Elegir fecha',
                      )
                    : IconButton(
                        onPressed: () => setState(() => _setDate(null)),
                        icon: const Icon(Icons.clear),
                        tooltip: 'Quitar fecha',
                      ),
              ),
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<MetaEstado>(
                initialValue: _state,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(Icons.info_outline),
                ),
                items: MetaEstado.values
                    .map(
                      (state) => DropdownMenuItem(
                        value: state,
                        child: Text(goalStateLabel(state)),
                      ),
                    )
                    .toList(),
                onChanged: controllerState.isLoading
                    ? null
                    : (value) => setState(() => _state = value!),
              ),
            ],
            const SizedBox(height: 28),
            const _SectionHeading(
              icon: Icons.link,
              title: 'Hábitos vinculados',
            ),
            const SizedBox(height: 8),
            if (habitsState.isLoading)
              const Center(child: CircularProgressIndicator())
            else if (habitsState.hasError)
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(habitsListProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar hábitos'),
              )
            else if (habits.isEmpty)
              const Text('Aún no tienes hábitos para vincular.')
            else
              ...habits.map(
                (habit) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selectedHabitIds.contains(habit.id),
                  onChanged: controllerState.isLoading
                      ? null
                      : (checked) => setState(() {
                          if (checked ?? false) {
                            _selectedHabitIds.add(habit.id);
                          } else {
                            _selectedHabitIds.remove(habit.id);
                          }
                        }),
                  title: Text(habit.nombre),
                  subtitle:
                      habit.metaId != null && habit.metaId != widget.goalId
                      ? const Text('Se reasignará desde otra meta.')
                      : null,
                  secondary: const Icon(Icons.checklist_outlined),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: FilledButton.icon(
            onPressed: controllerState.isLoading ? null : () => _save(original),
            icon: controllerState.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(widget.isEditing ? 'Guardar cambios' : 'Crear meta'),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 10),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
