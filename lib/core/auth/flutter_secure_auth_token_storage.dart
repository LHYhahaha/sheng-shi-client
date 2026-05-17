import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_token_snapshot.dart';
import 'auth_token_storage.dart';

/// 基于 [FlutterSecureStorage] 的 token 持久化实现。
///
/// 项目已依赖 `flutter_secure_storage`，真实登录接入时可通过
/// [authTokenStorageProvider] override 启用。当前默认仍使用 in-memory，
/// 避免 mock/测试环境依赖平台 secure channel。
class FlutterSecureAuthTokenStorage implements AuthTokenStorage {
  FlutterSecureAuthTokenStorage({
    FlutterSecureStorage? secureStorage,
    this.storageKey = 'drama.auth.token_snapshot',
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _emptyJson = '{}';

  final FlutterSecureStorage _secureStorage;
  final String storageKey;

  @override
  Future<AuthTokenSnapshot?> read() async {
    final raw = await _secureStorage.read(key: storageKey);
    if (raw == null || raw.isEmpty || raw == _emptyJson) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      final snapshot = AuthTokenSnapshot.fromJson(decoded);
      return snapshot.isEmpty ? null : snapshot;
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthTokenSnapshot snapshot) async {
    if (snapshot.isEmpty) {
      await clear();
      return;
    }

    await _secureStorage.write(
      key: storageKey,
      value: jsonEncode(snapshot.toJson()),
    );
  }

  @override
  Future<void> clear() async {
    await _secureStorage.delete(key: storageKey);
  }
}
