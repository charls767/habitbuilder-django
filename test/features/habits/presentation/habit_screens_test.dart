import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/categoria.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/meta_option.dart';
import 'package:habitbuilder_mobile/features/habits/domain/repositories/habit_repository.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/providers/habit_providers.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/screens/habit_form_screen.dart';
import 'package:habitbuilder_mobile/features/habits/presentation/screens/habits_list_screen.dart';

void main() {
  group('HabitsListScreen', () {
    testWidgets('renders configured habits and their frequency', (
      tester,
    ) async {
      await _pumpList(tester, [
        _habit(nombre: 'Leer', frecuencia: Frecuencia.diasSemana([1, 3, 5])),
        _habit(
          id: 'hab_2',
          nombre: 'Meditar',
          estado: HabitoEstado.pausado,
          frecuencia: Frecuencia.vecesPeriodo(3, PeriodoFrecuencia.semana),
        ),
      ]);

      expect(find.text('Hábitos del día'), findsOneWidget);
      expect(find.text('2 hábitos configurados'), findsOneWidget);
      expect(find.text('Leer'), findsOneWidget);
      expect(find.text('Días: Lun, Mié, Vie'), findsOneWidget);
      expect(find.text('3 veces por semana'), findsOneWidget);
      expect(find.text('Pausado'), findsOneWidget);
    });

    testWidgets('shows an actionable empty state', (tester) async {
      await _pumpList(tester, const []);

      expect(find.text('Tu lista está lista para empezar'), findsOneWidget);
      expect(find.text('Crear hábito'), findsOneWidget);
    });

    testWidgets('shows an actionable error state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            habitsListProvider.overrideWith(
              (ref) => Future<List<Habito>>.error(Exception('offline')),
            ),
          ],
          child: const MaterialApp(home: HabitsListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No pudimos cargar tus hábitos.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('HabitFormScreen', () {
    testWidgets('validates and creates a habit with all selectors', (
      tester,
    ) async {
      final repository = _FakeHabitRepository();
      await _pumpForm(tester, repository);

      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pump();
      expect(find.text('Escribe un nombre para el hábito'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Caminar',
      );
      await tester.tap(find.text('Semanal'));
      await tester.pump();
      await tester.drag(find.byType(ListView), const Offset(0, -140));
      await tester.pump();
      final wednesday = find.widgetWithText(FilterChip, 'X');
      await tester.tap(wednesday);
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -360));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin categoría'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salud'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin meta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dormir mejor'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(repository.createdName, 'Caminar');
      expect(repository.createdCategoryId, 'cat_health');
      expect(repository.createdGoalId, 'meta_sleep');
      final frequency = repository.createdFrequency;
      expect(frequency, isA<FrecuenciaDiasSemana>());
      expect((frequency! as FrecuenciaDiasSemana).diasSemana, [1, 3]);
    });

    testWidgets('hydrates and updates an existing habit', (tester) async {
      final repository = _FakeHabitRepository(
        habit: _habit(
          descripcion: 'Antes de dormir',
          categoriaId: 'cat_health',
          metaId: 'meta_sleep',
          frecuencia: Frecuencia.vecesPeriodo(4, PeriodoFrecuencia.mes),
        ),
      );
      await _pumpForm(tester, repository, habitId: 'hab_1');

      expect(find.text('Editar hábito'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Mes'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Leer treinta minutos',
      );
      await tester.tap(find.widgetWithText(TextButton, 'Guardar'));
      await tester.pumpAndSettle();

      expect(repository.updatedHabitId, 'hab_1');
      expect(repository.updatedName, 'Leer treinta minutos');
      expect(repository.updatedDescription?.isPresent, isTrue);
      expect(repository.updatedCategory?.value, 'cat_health');
      expect(repository.updatedGoal?.value, 'meta_sleep');
    });
  });
}

Future<void> _pumpList(WidgetTester tester, List<Habito> habits) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [habitsListProvider.overrideWith((ref) async => habits)],
      child: const MaterialApp(home: HabitsListScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpForm(
  WidgetTester tester,
  _FakeHabitRepository repository, {
  String? habitId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        habitRepositoryProvider.overrideWithValue(repository),
        categoriesListProvider.overrideWith(
          (ref) async => const [Categoria(id: 'cat_health', nombre: 'Salud')],
        ),
        goalOptionsListProvider.overrideWith(
          (ref) async => const [
            MetaOption(id: 'meta_sleep', nombre: 'Dormir mejor'),
          ],
        ),
      ],
      child: MaterialApp(home: HabitFormScreen(habitId: habitId)),
    ),
  );
  await tester.pumpAndSettle();
}

Habito _habit({
  String id = 'hab_1',
  String nombre = 'Leer',
  String? descripcion,
  String? categoriaId,
  String? metaId,
  Frecuencia? frecuencia,
  HabitoEstado estado = HabitoEstado.activo,
}) {
  return Habito(
    id: id,
    usuarioId: 'usr_1',
    nombre: nombre,
    descripcion: descripcion,
    categoriaId: categoriaId,
    metaId: metaId,
    fechaInicio: DateTime(2026, 7, 28),
    frecuencia: frecuencia ?? Frecuencia.diaria(),
    estado: estado,
    pausas: const [],
    fechaCreacion: DateTime.utc(2026, 7, 28),
    fechaActualizacion: DateTime.utc(2026, 7, 28),
  );
}

class _FakeHabitRepository implements HabitRepository {
  _FakeHabitRepository({Habito? habit}) : habit = habit ?? _habit();

  final Habito habit;
  String? createdName;
  String? createdCategoryId;
  String? createdGoalId;
  Frecuencia? createdFrequency;
  String? updatedHabitId;
  String? updatedName;
  PatchValue<String?>? updatedDescription;
  PatchValue<String?>? updatedCategory;
  PatchValue<String?>? updatedGoal;

  @override
  Future<List<Categoria>> listCategories() async => const [];

  @override
  Future<List<MetaOption>> listGoalOptions() async => const [];

  @override
  Future<List<Habito>> listHabits({HabitoEstado? estado}) async => [habit];

  @override
  Future<Habito> getHabit(String habitId) async => habit;

  @override
  Future<Habito> createHabit({
    required String nombre,
    required DateTime fechaInicio,
    required Frecuencia frecuencia,
    String? descripcion,
    String? categoriaId,
    String? metaId,
  }) async {
    createdName = nombre;
    createdCategoryId = categoriaId;
    createdGoalId = metaId;
    createdFrequency = frecuencia;
    return habit;
  }

  @override
  Future<Habito> updateHabit({
    required String habitId,
    String? nombre,
    PatchValue<String?> descripcion = const PatchValue<String?>.absent(),
    PatchValue<String?> categoriaId = const PatchValue<String?>.absent(),
    PatchValue<String?> metaId = const PatchValue<String?>.absent(),
    DateTime? fechaInicio,
    Frecuencia? frecuencia,
  }) async {
    updatedHabitId = habitId;
    updatedName = nombre;
    updatedDescription = descripcion;
    updatedCategory = categoriaId;
    updatedGoal = metaId;
    return habit;
  }

  @override
  Future<void> deleteHabit(String habitId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
