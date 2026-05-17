import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/api_service.dart';

part 'auth_providers.g.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<AuthStatus> build() async {
    final api = ref.read(apiServiceProvider);
    final loggedIn = await api.isLoggedIn();
    return loggedIn ? AuthStatus.authenticated : AuthStatus.unauthenticated;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(apiServiceProvider).login(email, password);
      state = const AsyncValue.data(AuthStatus.authenticated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> register(String email, String username, String password) async {
    state = const AsyncValue.loading();
    try {
      await ref.read(apiServiceProvider).register(email, username, password);
      state = const AsyncValue.data(AuthStatus.authenticated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logout() async {
    await ref.read(apiServiceProvider).logout();
    state = const AsyncValue.data(AuthStatus.unauthenticated);
  }
}
