import 'package:dio/dio.dart';

import '../../../../core/network/api_exception.dart';
import '../models/perfil_usuario_dto.dart';

class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._dio);

  final Dio _dio;

  Future<PerfilUsuarioDto> getMyProfile() async {
    return runApiCall(() async {
      final response = await _dio.get<Map<String, dynamic>>('/users/me');
      return PerfilUsuarioDto.fromJson(response.data!);
    });
  }

  Future<PerfilUsuarioDto> updateMyProfile(Map<String, dynamic> patch) async {
    return runApiCall(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/users/me',
        data: patch,
      );
      return PerfilUsuarioDto.fromJson(response.data!);
    });
  }
}
