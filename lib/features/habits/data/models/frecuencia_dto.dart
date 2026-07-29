import '../../domain/entities/frecuencia.dart';

sealed class FrecuenciaDto {
  const FrecuenciaDto();

  factory FrecuenciaDto.fromJson(Map<String, dynamic> json) {
    final tipo = FrecuenciaTipo.fromApiValue(json['tipo'] as String);
    return switch (tipo) {
      FrecuenciaTipo.diaria => const FrecuenciaDiariaDto(),
      FrecuenciaTipo.diasSemana => FrecuenciaDiasSemanaDto(
        (json['diasSemana'] as List<dynamic>).cast<int>(),
      ),
      FrecuenciaTipo.vecesPeriodo => FrecuenciaVecesPeriodoDto(
        veces: json['veces'] as int,
        periodo: PeriodoFrecuencia.fromApiValue(json['periodo'] as String),
      ),
    };
  }

  factory FrecuenciaDto.fromEntity(Frecuencia frecuencia) {
    return switch (frecuencia) {
      FrecuenciaDiaria() => const FrecuenciaDiariaDto(),
      FrecuenciaDiasSemana(:final diasSemana) => FrecuenciaDiasSemanaDto(
        diasSemana,
      ),
      FrecuenciaVecesPeriodo(:final veces, :final periodo) =>
        FrecuenciaVecesPeriodoDto(veces: veces, periodo: periodo),
    };
  }

  FrecuenciaTipo get tipo;

  Map<String, dynamic> toJson();

  Frecuencia toEntity();
}

final class FrecuenciaDiariaDto extends FrecuenciaDto {
  const FrecuenciaDiariaDto();

  @override
  FrecuenciaTipo get tipo => FrecuenciaTipo.diaria;

  @override
  Map<String, dynamic> toJson() => {'tipo': tipo.apiValue};

  @override
  Frecuencia toEntity() => Frecuencia.diaria();
}

final class FrecuenciaDiasSemanaDto extends FrecuenciaDto {
  FrecuenciaDiasSemanaDto(List<int> diasSemana)
    : diasSemana = List<int>.unmodifiable(diasSemana);

  final List<int> diasSemana;

  @override
  FrecuenciaTipo get tipo => FrecuenciaTipo.diasSemana;

  @override
  Map<String, dynamic> toJson() => {
    'tipo': tipo.apiValue,
    'diasSemana': diasSemana,
  };

  @override
  Frecuencia toEntity() => Frecuencia.diasSemana(diasSemana);
}

final class FrecuenciaVecesPeriodoDto extends FrecuenciaDto {
  const FrecuenciaVecesPeriodoDto({required this.veces, required this.periodo});

  final int veces;
  final PeriodoFrecuencia periodo;

  @override
  FrecuenciaTipo get tipo => FrecuenciaTipo.vecesPeriodo;

  @override
  Map<String, dynamic> toJson() => {
    'tipo': tipo.apiValue,
    'veces': veces,
    'periodo': periodo.apiValue,
  };

  @override
  Frecuencia toEntity() => Frecuencia.vecesPeriodo(veces, periodo);
}
