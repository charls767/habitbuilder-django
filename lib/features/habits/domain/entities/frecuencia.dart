enum FrecuenciaTipo {
  diaria('diaria'),
  diasSemana('dias_semana'),
  vecesPeriodo('veces_periodo');

  const FrecuenciaTipo(this.apiValue);

  factory FrecuenciaTipo.fromApiValue(String value) {
    return values.firstWhere(
      (tipo) => tipo.apiValue == value,
      orElse: () =>
          throw FormatException('Tipo de frecuencia desconocido: $value'),
    );
  }

  final String apiValue;
}

enum PeriodoFrecuencia {
  semana('semana'),
  mes('mes');

  const PeriodoFrecuencia(this.apiValue);

  factory PeriodoFrecuencia.fromApiValue(String value) {
    return values.firstWhere(
      (periodo) => periodo.apiValue == value,
      orElse: () =>
          throw FormatException('Periodo de frecuencia desconocido: $value'),
    );
  }

  final String apiValue;
}

sealed class Frecuencia {
  const Frecuencia._();

  factory Frecuencia.diaria() = FrecuenciaDiaria;

  factory Frecuencia.diasSemana(List<int> diasSemana) = FrecuenciaDiasSemana;

  factory Frecuencia.vecesPeriodo(int veces, PeriodoFrecuencia periodo) =
      FrecuenciaVecesPeriodo;

  FrecuenciaTipo get tipo;
}

final class FrecuenciaDiaria extends Frecuencia {
  const FrecuenciaDiaria() : super._();

  @override
  FrecuenciaTipo get tipo => FrecuenciaTipo.diaria;
}

final class FrecuenciaDiasSemana extends Frecuencia {
  FrecuenciaDiasSemana(List<int> diasSemana)
    : diasSemana = List<int>.unmodifiable(_validateDiasSemana(diasSemana)),
      super._();

  final List<int> diasSemana;

  @override
  FrecuenciaTipo get tipo => FrecuenciaTipo.diasSemana;
}

final class FrecuenciaVecesPeriodo extends Frecuencia {
  FrecuenciaVecesPeriodo(this.veces, this.periodo) : super._() {
    if (veces < 1 || veces > 31) {
      throw RangeError.range(veces, 1, 31, 'veces');
    }
  }

  final int veces;
  final PeriodoFrecuencia periodo;

  @override
  FrecuenciaTipo get tipo => FrecuenciaTipo.vecesPeriodo;
}

List<int> _validateDiasSemana(List<int> diasSemana) {
  if (diasSemana.isEmpty) {
    throw ArgumentError.value(
      diasSemana,
      'diasSemana',
      'Debe incluir al menos un dia.',
    );
  }
  if (diasSemana.any((dia) => dia < 1 || dia > 7)) {
    throw ArgumentError.value(
      diasSemana,
      'diasSemana',
      'Cada dia debe estar entre 1 y 7.',
    );
  }
  if (diasSemana.toSet().length != diasSemana.length) {
    throw ArgumentError.value(
      diasSemana,
      'diasSemana',
      'Los dias no pueden repetirse.',
    );
  }
  return diasSemana;
}
