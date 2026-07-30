import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/auth_session_controller.dart';
import '../../../../core/network/dio_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/profile_remote_data_source.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/perfil_usuario.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';

part 'profile_providers.g.dart';

@riverpod
ProfileRemoteDataSource profileRemoteDataSource(Ref ref) {
  return ProfileRemoteDataSource(ref.watch(dioProvider));
}

@riverpod
ProfileRepository profileRepository(Ref ref) {
  return ProfileRepositoryImpl(ref.watch(profileRemoteDataSourceProvider));
}

@riverpod
Future<PerfilUsuario> myProfile(Ref ref) {
  return ref.watch(profileRepositoryProvider).getMyProfile();
}

@riverpod
class ProfileController extends _$ProfileController {
  @override
  FutureOr<void> build() {}

  Future<void> updateProfile({
    required String nombreCompleto,
    required String objetivoGeneral,
    required String zonaHoraria,
    required AccessibilityPreferences accessibility,
    required NotificationPreferences notifications,
  }) async {
    final reconcile = ref.read(reminderReconciliationRequestProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(profileRepositoryProvider)
          .updateMyProfile(
            nombreCompleto: nombreCompleto,
            objetivoGeneral: objetivoGeneral,
            zonaHoraria: zonaHoraria,
            accessibility: accessibility,
            notifications: notifications,
          );
    });
    final success = !state.hasError;
    if (success) {
      ref.invalidate(myProfileProvider);
      await reconcile(
        requestPermission:
            notifications.enabled && notifications.habitReminders,
      );
    }
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    await ref
        .read(authSessionControllerProvider.notifier)
        .markUnauthenticated();
  }
}
