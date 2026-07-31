/// Wire shape for the backend `SesionResponse` schema.
class TokenPairDto {
  const TokenPairDto({
    required this.accessToken,
    this.refreshToken,
    this.expiresIn,
  });

  factory TokenPairDto.fromJson(Map<String, dynamic> json) {
    final expiration = json['expiraEn'] as String?;
    final expiresIn = expiration == null
        ? json['expiresIn'] as int?
        : DateTime.parse(
            expiration,
          ).difference(DateTime.now().toUtc()).inSeconds;
    return TokenPairDto(
      accessToken: (json['token'] ?? json['accessToken']) as String,
      refreshToken: json['refreshToken'] as String?,
      expiresIn: expiresIn,
    );
  }

  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
}
