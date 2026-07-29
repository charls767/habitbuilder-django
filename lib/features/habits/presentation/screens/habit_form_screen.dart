import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/app_chrome.dart';
import '../../domain/entities/categoria.dart';
import '../../domain/entities/frecuencia.dart';
import '../../domain/entities/habito.dart';
import '../../domain/entities/meta_option.dart';
import '../providers/habit_providers.dart';

class HabitFormScreen extends ConsumerStatefulWidget {
  const HabitFormScreen({super.key, this.habitId});

  final String? habitId;

  bool get isEditing => habitId != null;

  @override
  ConsumerState<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends ConsumerState<HabitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();

  String? _hydratedHabitId;
  DateTime _startDate = DateTime.now();
  FrecuenciaTipo _frequencyType = FrecuenciaTipo.diaria;
  final Set<int> _weekdays = {1};
  int _times = 3;
  PeriodoFrecuencia _period = PeriodoFrecuencia.semana;
  String? _categoryId;
  String? _goalId;

  @override
  void initState() {
    super.initState();
    _setDate(DateTime.now());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _hydrate(Habito habit) {
    if (_hydratedHabitId == habit.id) return;
    _hydratedHabitId = habit.id;
    _nameController.text = habit.nombre;
    _descriptionController.text = habit.descripcion ?? '';
    _setDate(habit.fechaInicio);
    _frequencyType = habit.frecuencia.tipo;
    switch (habit.frecuencia) {
      case FrecuenciaDiaria():
        break;
      case FrecuenciaDiasSemana(:final diasSemana):
        _weekdays
          ..clear()
          ..addAll(diasSemana);
      case FrecuenciaVecesPeriodo(:final veces, :final periodo):
        _times = veces;
        _period = periodo;
    }
    _categoryId = habit.categoriaId;
    _goalId = habit.metaId;
  }

  void _setDate(DateTime value) {
    _startDate = DateTime(value.year, value.month, value.day);
    _dateController.text =
        '${_startDate.day.toString().padLeft(2, '0')}/'
        '${_startDate.month.toString().padLeft(2, '0')}/'
        '${_startDate.year}';
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: 'Fecha de inicio',
    );
    if (selected != null) {
      setState(() => _setDate(selected));
    }
  }

  Frecuencia _buildFrequency() {
    return switch (_frequencyType) {
      FrecuenciaTipo.diaria => Frecuencia.diaria(),
      FrecuenciaTipo.diasSemana => Frecuencia.diasSemana(
        _weekdays.toList()..sort(),
      ),
      FrecuenciaTipo.vecesPeriodo => Frecuencia.vecesPeriodo(_times, _period),
    };
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final controller = ref.read(habitControllerProvider.notifier);
    final description = _descriptionController.text.trim();
    final success = widget.isEditing
        ? await controller.updateHabit(
            habitId: widget.habitId!,
            nombre: _nameController.text.trim(),
            descripcion: description.isEmpty ? null : description,
            fechaInicio: _startDate,
            frecuencia: _buildFrequency(),
            categoriaId: _categoryId,
            metaId: _goalId,
          )
        : await controller.createHabit(
            nombre: _nameController.text.trim(),
            descripcion: description.isEmpty ? null : description,
            fechaInicio: _startDate,
            frecuencia: _buildFrequency(),
            categoriaId: _categoryId,
            metaId: _goalId,
          );

    if (!mounted) return;
    if (success) {
      await Navigator.of(context).maybePop();
      return;
    }

    final error = ref.read(habitControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error is ApiException
              ? error.message
              : 'No se pudo guardar el hábito. Revisa tu conexión.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEditing) {
      return _buildForm();
    }

    return ref
        .watch(habitDetailProvider(widget.habitId!))
        .when(
          data: (habit) {
            _hydrate(habit);
            return _buildForm();
          },
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Editar hábito')),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Scaffold(
            appBar: AppBar(title: const Text('Editar hábito')),
            body: Center(
              child: OutlinedButton.icon(
                onPressed: () =>
                    ref.invalidate(habitDetailProvider(widget.habitId!)),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ),
          ),
        );
  }

  Widget _buildForm() {
    final controllerState = ref.watch(habitControllerProvider);
    final categories = ref.watch(categoriesListProvider).value ?? const [];
    final goals = ref.watch(goalOptionsListProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar hábito' : 'Nuevo hábito'),
        leadingWidth: 84,
        leading: TextButton(
          onPressed: controllerState.isLoading
              ? null
              : () => Navigator.of(context).maybePop(),
          child: const Text('Cancelar'),
        ),
        actions: [
          TextButton(
            onPressed: controllerState.isLoading ? null : _save,
            child: controllerState.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AppContent(
        maxWidth: 640,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              const AppSectionLabel('Nombre del hábito'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                autofocus: !widget.isEditing,
                maxLength: 120,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej. Meditar al despertar',
                  counterText: '',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe un nombre para el hábito'
                    : null,
              ),
              const SizedBox(height: 20),
              const AppSectionLabel('Descripción'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Añade una nota opcional',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              _CategoryField(
                categories: categories,
                value: _categoryId,
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 20),
              const AppSectionLabel('Frecuencia'),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<FrecuenciaTipo>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: FrecuenciaTipo.diaria,
                      label: Text('Diaria'),
                    ),
                    ButtonSegment(
                      value: FrecuenciaTipo.diasSemana,
                      label: Text('Semanal'),
                    ),
                    ButtonSegment(
                      value: FrecuenciaTipo.vecesPeriodo,
                      label: Text('Personal.'),
                    ),
                  ],
                  selected: {_frequencyType},
                  onSelectionChanged: controllerState.isLoading
                      ? null
                      : (selection) =>
                            setState(() => _frequencyType = selection.first),
                ),
              ),
              const SizedBox(height: 14),
              if (_frequencyType == FrecuenciaTipo.diasSemana)
                _WeekdayPicker(
                  selected: _weekdays,
                  onChanged: (days) => setState(() {
                    _weekdays
                      ..clear()
                      ..addAll(days);
                  }),
                ),
              if (_frequencyType == FrecuenciaTipo.vecesPeriodo)
                _TimesPerPeriodPicker(
                  times: _times,
                  period: _period,
                  onTimesChanged: (value) => setState(() => _times = value),
                  onPeriodChanged: (value) => setState(() => _period = value),
                ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final dateField = TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: InputDecoration(
                      labelText: 'Fecha de inicio',
                      suffixIcon: IconButton(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today_outlined),
                        tooltip: 'Elegir fecha',
                      ),
                    ),
                  );
                  final goalField = _GoalField(
                    goals: goals,
                    value: _goalId,
                    onChanged: (value) => setState(() => _goalId = value),
                  );
                  if (constraints.maxWidth < 360) {
                    return Column(
                      children: [
                        dateField,
                        const SizedBox(height: 12),
                        goalField,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: dateField),
                      const SizedBox(width: 12),
                      Expanded(child: goalField),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({required this.selected, required this.onChanged});

  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Días de la semana',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (index) {
            final day = index + 1;
            return FilterChip(
              label: Text(labels[index]),
              selected: selected.contains(day),
              onSelected: (isSelected) {
                final updated = {...selected};
                if (isSelected) {
                  updated.add(day);
                } else if (updated.length > 1) {
                  updated.remove(day);
                }
                onChanged(updated);
              },
            );
          }),
        ),
      ],
    );
  }
}

class _TimesPerPeriodPicker extends StatelessWidget {
  const _TimesPerPeriodPicker({
    required this.times,
    required this.period,
    required this.onTimesChanged,
    required this.onPeriodChanged,
  });

  final int times;
  final PeriodoFrecuencia period;
  final ValueChanged<int> onTimesChanged;
  final ValueChanged<PeriodoFrecuencia> onPeriodChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cantidad de veces',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.filledTonal(
              onPressed: times > 1 ? () => onTimesChanged(times - 1) : null,
              icon: const Icon(Icons.remove),
              tooltip: 'Disminuir',
            ),
            SizedBox(
              width: 64,
              child: Text(
                '$times',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton.filledTonal(
              onPressed: times < 31 ? () => onTimesChanged(times + 1) : null,
              icon: const Icon(Icons.add),
              tooltip: 'Aumentar',
            ),
            const SizedBox(width: 20),
            Expanded(
              child: SegmentedButton<PeriodoFrecuencia>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: PeriodoFrecuencia.semana,
                    label: Text('Semana'),
                  ),
                  ButtonSegment(
                    value: PeriodoFrecuencia.mes,
                    label: Text('Mes'),
                  ),
                ],
                selected: {period},
                onSelectionChanged: (selection) =>
                    onPeriodChanged(selection.first),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryField extends StatelessWidget {
  const _CategoryField({
    required this.categories,
    required this.value,
    required this.onChanged,
  });

  final List<Categoria> categories;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = categories.any((item) => item.id == value)
        ? value
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionLabel('Categoría'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Sin categoría'),
              selected: effectiveValue == null,
              onSelected: (_) => onChanged(null),
            ),
            ...categories.map(
              (category) => ChoiceChip(
                label: Text(category.nombre),
                selected: effectiveValue == category.id,
                onSelected: (_) => onChanged(category.id),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GoalField extends StatelessWidget {
  const _GoalField({
    required this.goals,
    required this.value,
    required this.onChanged,
  });

  final List<MetaOption> goals;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final effectiveValue = goals.any((item) => item.id == value) ? value : null;
    return DropdownButtonFormField<String?>(
      key: ValueKey('goal-$value-${goals.length}'),
      initialValue: effectiveValue,
      decoration: const InputDecoration(labelText: 'Meta vinculada'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Sin meta')),
        ...goals.map(
          (goal) => DropdownMenuItem<String?>(
            value: goal.id,
            child: Text(goal.nombre),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
