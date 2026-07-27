import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/token_storage.dart';

part 'auth_session_controller.g.dart';

/// Whether the app currently holds a usable session (a stored access token).
///
/// This is the single source of truth [lib/core/router/app_router.dart]
/// redirects on, and what [JwtInterceptor] flips to `false` when a token
/// refresh fails.
@riverpod
class AuthSessionController extends _$AuthSessionController {
  @override
  Future<bool> build() async {
    final storage = ref.watch(tokenStorageProvider);
    final accessToken = await storage.readAccessToken();
    return accessToken != null;
  }

  void markAuthenticated() {
    state = const AsyncData(true);
  }

  Future<void> markUnauthenticated() async {
    await ref.read(tokenStorageProvider).clear();
    state = const AsyncData(false);
  }
}
