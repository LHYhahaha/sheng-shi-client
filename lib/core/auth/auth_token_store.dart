import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_token_snapshot.dart';
import 'auth_token_storage.dart';
import 'auth_token_storage_provider.dart';

export 'auth_token_snapshot.dart';

final authTokenStoreProvider =
    NotifierProvider<AuthTokenStore, AuthTokenSnapshot>(AuthTokenStore.new);

/// Token 应用层唯一读写入口。
///
/// 内部委托 [AuthTokenStorage] 持久化；当前默认 in-memory，真实阶段替换 storage
/// provider 即可，无需改 UI 或 feature repository。
class AuthTokenStore extends Notifier<AuthTokenSnapshot> {
  bool _hydrateFinished = false;

  @override
  AuthTokenSnapshot build() {
    Future.microtask(_hydrateFromStorage);
    return const AuthTokenSnapshot.empty();
  }

  AuthTokenStorage get _storage => ref.read(authTokenStorageProvider);

  Future<void> _hydrateFromStorage() async {
    if (_hydrateFinished) {
      return;
    }
    _hydrateFinished = true;

    final stored = await _storage.read();
    if (stored != null && !stored.isEmpty) {
      state = stored;
    }
  }

  Future<void> save(AuthTokenSnapshot token) async {
    _hydrateFinished = true;
    await _storage.write(token);
    state = token;
  }

  Future<void> clear() async {
    _hydrateFinished = true;
    await _storage.clear();
    state = const AuthTokenSnapshot.empty();
  }
}
