/// Wire shape for the `TokenPair` schema in `docs/openapi.yaml`.
class TokenPairDto {
  const TokenPairDto({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory TokenPairDto.fromJson(Map<String, dynamic> json) => TokenPairDto(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    expiresIn: json['expiresIn'] as int,
  );

  final String accessToken;
  final String refreshToken;
  final int expiresIn;
}
