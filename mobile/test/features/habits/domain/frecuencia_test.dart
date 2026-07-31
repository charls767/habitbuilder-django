import 'package:flutter_test/flutter_test.dart';
import 'package:habitbuilder_mobile/features/habits/domain/entities/frecuencia.dart';

void main() {
  group('Frecuencia', () {
    test('creates the three public variants with compatible enum names', () {
      final diaria = Frecuencia.diaria();
      final diasSemana = Frecuencia.diasSemana([1, 3, 5]);
      final vecesPeriodo = Frecuencia.vecesPeriodo(3, PeriodoFrecuencia.semana);

      expect(diaria, isA<FrecuenciaDiaria>());
      expect(diaria.tipo, FrecuenciaTipo.diaria);
      expect(diasSemana, isA<FrecuenciaDiasSemana>());
      expect(diasSemana.tipo, FrecuenciaTipo.diasSemana);
      expect((diasSemana as FrecuenciaDiasSemana).diasSemana, [1, 3, 5]);
      expect(vecesPeriodo, isA<FrecuenciaVecesPeriodo>());
      expect(vecesPeriodo.tipo, FrecuenciaTipo.vecesPeriodo);
      expect((vecesPeriodo as FrecuenciaVecesPeriodo).veces, 3);
      expect(vecesPeriodo.periodo, PeriodoFrecuencia.semana);
    });

    test('exposes exact API discriminator values', () {
      expect(FrecuenciaTipo.diaria.apiValue, 'diaria');
      expect(FrecuenciaTipo.diasSemana.apiValue, 'dias_semana');
      expect(FrecuenciaTipo.vecesPeriodo.apiValue, 'veces_periodo');
      expect(PeriodoFrecuencia.semana.apiValue, 'semana');
      expect(PeriodoFrecuencia.mes.apiValue, 'mes');

      expect(
        FrecuenciaTipo.fromApiValue('dias_semana'),
        FrecuenciaTipo.diasSemana,
      );
      expect(PeriodoFrecuencia.fromApiValue('mes'), PeriodoFrecuencia.mes);
    });

    test('rejects unknown discriminator values', () {
      expect(
        () => FrecuenciaTipo.fromApiValue('cada_dia'),
        throwsFormatException,
      );
      expect(
        () => PeriodoFrecuencia.fromApiValue('anio'),
        throwsFormatException,
      );
    });

    test('enforces unique weekdays in the OpenAPI range', () {
      expect(() => Frecuencia.diasSemana([]), throwsArgumentError);
      expect(() => Frecuencia.diasSemana([0]), throwsArgumentError);
      expect(() => Frecuencia.diasSemana([8]), throwsArgumentError);
      expect(() => Frecuencia.diasSemana([1, 1]), throwsArgumentError);
    });

    test('copies weekdays and exposes an unmodifiable list', () {
      final source = [1, 2];
      final frecuencia = Frecuencia.diasSemana(source) as FrecuenciaDiasSemana;
      source.add(3);

      expect(frecuencia.diasSemana, [1, 2]);
      expect(() => frecuencia.diasSemana.add(4), throwsUnsupportedError);
    });

    test('enforces veces between 1 and 31', () {
      expect(
        () => Frecuencia.vecesPeriodo(0, PeriodoFrecuencia.semana),
        throwsRangeError,
      );
      expect(
        () => Frecuencia.vecesPeriodo(32, PeriodoFrecuencia.mes),
        throwsRangeError,
      );
    });
  });
}
