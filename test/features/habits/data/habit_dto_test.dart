import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/categoria_dto.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/frecuencia_dto.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/habito_dto.dart';
import 'package:habitbuilder_mobile/features/habits/data/models/meta_option_dto.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/habito.dart';
import 'package:habitbuilder_mobile/features/habits/domain/repositories/habit_repository.dart';

void main() {
  group('CategoriaDto', () {
    test('maps all contract fields', () {
      final dto = CategoriaDto.fromJson({
        'id': 'cat_salud',
        'nombre': 'Salud fisica',
        'colorHex': '#4CAF50',
        'icono': 'fitness_center',
      });

      expect(dto.toJson(), {
        'id': 'cat_salud',
        'nombre': 'Salud fisica',
        'colorHex': '#4CAF50',
        'icono': 'fitness_center',
      });
      expect(dto.toEntity().nombre, 'Salud fisica');
    });

    test('supports optional visual fields', () {
      final dto = CategoriaDto.fromJson({'id': 'cat_otra', 'nombre': 'Otra'});

      expect(dto.colorHex, isNull);
      expect(dto.icono, isNull);
      expect(dto.toJson(), {'id': 'cat_otra', 'nombre': 'Otra'});
    });
  });

  test('MetaOptionDto projects id and nombre from a full goal payload', () {
    final option = MetaOptionDto.fromJson({
      'id': 'meta_001',
      'usuarioId': 'usr_001',
      'nombre': 'Reducir el estres',
      'estado': 'en_progreso',
      'habitoIds': <String>[],
      'progresoPorcentaje': 0,
      'fechaCreacion': '2026-07-28T14:00:00Z',
      'fechaActualizacion': '2026-07-28T14:30:00Z',
    }).toEntity();

    expect(option.id, 'meta_001');
    expect(option.nombre, 'Reducir el estres');
  });

  group('FrecuenciaDto', () {
    test('parses and serializes diaria', () {
      final dto = FrecuenciaDto.fromJson({'tipo': 'diaria'});

      expect(dto, isA<FrecuenciaDiariaDto>());
      expect(dto.tipo, FrecuenciaTipo.diaria);
      expect(dto.toJson(), {'tipo': 'diaria'});
      expect(dto.toEntity(), isA<FrecuenciaDiaria>());
    });

    test('parses and serializes dias_semana', () {
      final dto = FrecuenciaDto.fromJson({
        'tipo': 'dias_semana',
        'diasSemana': [1, 3, 5],
      });

      expect(dto, isA<FrecuenciaDiasSemanaDto>());
      expect(dto.toJson(), {
        'tipo': 'dias_semana',
        'diasSemana': [1, 3, 5],
      });
      final entity = dto.toEntity() as FrecuenciaDiasSemana;
      expect(entity.diasSemana, [1, 3, 5]);
    });

    test('parses and serializes veces_periodo', () {
      final dto = FrecuenciaDto.fromJson({
        'tipo': 'veces_periodo',
        'veces': 4,
        'periodo': 'mes',
      });

      expect(dto, isA<FrecuenciaVecesPeriodoDto>());
      expect(dto.toJson(), {
        'tipo': 'veces_periodo',
        'veces': 4,
        'periodo': 'mes',
      });
      final entity = dto.toEntity() as FrecuenciaVecesPeriodo;
      expect(entity.veces, 4);
      expect(entity.periodo, PeriodoFrecuencia.mes);
    });

    test('creates every DTO variant from its domain factory', () {
      expect(
        FrecuenciaDto.fromEntity(Frecuencia.diaria()),
        isA<FrecuenciaDiariaDto>(),
      );
      expect(
        FrecuenciaDto.fromEntity(Frecuencia.diasSemana([2, 4])),
        isA<FrecuenciaDiasSemanaDto>(),
      );
      expect(
        FrecuenciaDto.fromEntity(
          Frecuencia.vecesPeriodo(2, PeriodoFrecuencia.semana),
        ),
        isA<FrecuenciaVecesPeriodoDto>(),
      );
    });

    test('rejects unknown discriminators', () {
      expect(
        () => FrecuenciaDto.fromJson({'tipo': 'quincenal'}),
        throwsFormatException,
      );
    });
  });

  group('HabitoDto', () {
    test('maps every response field, pause and timestamp', () {
      final dto = HabitoDto.fromJson(_fullHabitJson());
      final habit = dto.toEntity();

      expect(habit.id, 'hab_001');
      expect(habit.usuarioId, 'usr_001');
      expect(habit.nombre, 'Meditar 10 minutos');
      expect(habit.descripcion, 'Meditacion guiada');
      expect(habit.categoriaId, 'cat_salud');
      expect(habit.metaId, 'meta_001');
      expect(habit.fechaInicio, DateTime(2026, 7, 28));
      expect(habit.frecuencia, isA<FrecuenciaDiasSemana>());
      expect(habit.estado, HabitoEstado.pausado);
      expect(habit.pausas.single.id, 'pause_001');
      expect(habit.pausas.single.fechaInicio, DateTime(2026, 8, 1));
      expect(habit.pausas.single.fechaFin, DateTime(2026, 8, 3));
      expect(habit.fechaCompletado, DateTime.utc(2026, 9, 1, 10));
      expect(habit.fechaCreacion, DateTime.utc(2026, 1, 12, 8));
      expect(habit.fechaActualizacion, DateTime.utc(2026, 7, 28, 14, 30));

      expect(dto.toJson(), _fullHabitJson());
    });

    test('maps nullable response fields and open pauses', () {
      final json = _fullHabitJson()
        ..['descripcion'] = null
        ..['categoria'] = null
        ..['metaId'] = null
        ..['fechaCompletado'] = null
        ..['pausas'] = [
          {'id': 'pause_open', 'fechaInicio': '2026-08-01', 'fechaFin': null},
        ];
      final habit = HabitoDto.fromJson(json).toEntity();

      expect(habit.descripcion, isNull);
      expect(habit.categoriaId, isNull);
      expect(habit.metaId, isNull);
      expect(habit.fechaCompletado, isNull);
      expect(habit.pausas.single.fechaFin, isNull);
    });
  });

  group('request DTOs', () {
    test('create serializes required date and discriminated frequency', () {
      final dto = HabitoCreateRequestDto(
        nombre: 'Leer',
        descripcion: 'Veinte paginas',
        categoriaId: 'cat_aprender',
        metaId: 'meta_lectura',
        fechaInicio: DateTime(2026, 7, 9, 22, 10),
        frecuencia: FrecuenciaDto.fromEntity(Frecuencia.diaria()),
      );

      expect(dto.toJson(), {
        'nombre': 'Leer',
        'descripcion': 'Veinte paginas',
        'categoria': 'cat_aprender',
        'metaId': 'meta_lectura',
        'fechaInicio': '2026-07-09',
        'frecuencia': {'tipo': 'diaria'},
      });
    });

    test('create omits optional null fields', () {
      final dto = HabitoCreateRequestDto(
        nombre: 'Caminar',
        fechaInicio: DateTime(2026, 7, 28),
        frecuencia: const FrecuenciaDiariaDto(),
      );

      expect(dto.toJson().keys, {'nombre', 'fechaInicio', 'frecuencia'});
    });

    test('update distinguishes absent fields from explicit null', () {
      const empty = HabitoUpdateRequestDto();
      const clearFields = HabitoUpdateRequestDto(
        descripcion: PatchValue<String?>.present(null),
        categoriaId: PatchValue<String?>.present(null),
        metaId: PatchValue<String?>.present(null),
      );

      expect(empty.hasChanges, isFalse);
      expect(empty.toJson(), isEmpty);
      expect(clearFields.hasChanges, isTrue);
      expect(clearFields.toJson(), {
        'descripcion': null,
        'categoria': null,
        'metaId': null,
      });
    });

    test('update serializes every configurable field', () {
      final dto = HabitoUpdateRequestDto(
        nombre: 'Nuevo nombre',
        descripcion: const PatchValue<String?>.present('Descripcion'),
        categoriaId: const PatchValue<String?>.present('cat_2'),
        metaId: const PatchValue<String?>.present('meta_2'),
        fechaInicio: DateTime(2026, 8, 2),
        frecuencia: FrecuenciaDiasSemanaDto([2, 6]),
      );

      expect(dto.toJson(), {
        'nombre': 'Nuevo nombre',
        'descripcion': 'Descripcion',
        'categoria': 'cat_2',
        'metaId': 'meta_2',
        'frecuencia': {
          'tipo': 'dias_semana',
          'diasSemana': [2, 6],
        },
      });
    });
  });
}

Map<String, dynamic> _fullHabitJson() {
  return {
    'id': 'hab_001',
    'usuarioId': 'usr_001',
    'nombre': 'Meditar 10 minutos',
    'descripcion': 'Meditacion guiada',
    'categoria': 'cat_salud',
    'metaId': 'meta_001',
    'fechaInicio': '2026-07-28',
    'frecuencia': {
      'tipo': 'dias_semana',
      'diasSemana': [1, 3, 5],
    },
    'estado': 'pausado',
    'pausas': [
      {
        'id': 'pause_001',
        'fechaInicio': '2026-08-01',
        'fechaFin': '2026-08-03',
      },
    ],
    'fechaCompletado': '2026-09-01T10:00:00.000Z',
    'fechaCreacion': '2026-01-12T08:00:00.000Z',
    'fechaActualizacion': '2026-07-28T14:30:00.000Z',
  };
}
