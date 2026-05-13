import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository_provider.dart';
import '../domain/auth_session.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthState {
  const AuthState({
    required this.isLoading,
    required this.session,
    this.pendingProvider,
    this.error,
  });

  const AuthState.initial()
    : isLoading = true,
      session = const AuthSession.guest(),
      pendingProvider = null,
      error = null;

  final bool isLoading;
  final AuthSession session;
  final AuthProviderType? pendingProvider;
  final Object? error;

  bool get isLoggedIn => session.isLoggedIn;

  AuthUser? get user => session.user;

  AuthState copyWith({
    bool? isLoading,
    AuthSession? session,
    AuthProviderType? pendingProvider,
    Object? error,
    bool clearPendingProvider = false,
    bool clearError = false,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      session: session ?? this.session,
      pendingProvider: clearPendingProvider
          ? null
          : pendingProvider ?? this.pendingProvider,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  int _generation = 0;

  @override
  AuthState build() => const AuthState.initial();

  Future<void> load() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final session = await ref.read(authRepositoryProvider).fetchSession();
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        session: session,
        clearError: true,
        clearPendingProvider: true,
      );
    } catch (error) {
      if (!_isCurrent(generation)) {
        return;
      }
      state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> login(AuthProviderType provider) async {
    state = state.copyWith(pendingProvider: provider, clearError: true);

    try {
      final session = await ref.read(authRepositoryProvider).login(provider);
      state = state.copyWith(
        isLoading: false,
        session: session,
        clearPendingProvider: true,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error,
        clearPendingProvider: true,
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final session = await ref.read(authRepositoryProvider).logout();
    state = state.copyWith(
      isLoading: false,
      session: session,
      clearError: true,
      clearPendingProvider: true,
    );
  }

  Future<void> deleteAccount() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final session = await ref.read(authRepositoryProvider).deleteAccount();
    state = state.copyWith(
      isLoading: false,
      session: session,
      clearError: true,
      clearPendingProvider: true,
    );
  }

  bool _isCurrent(int generation) => generation == _generation;
}
