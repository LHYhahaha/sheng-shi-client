import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_token_storage.dart';
import 'in_memory_auth_token_storage.dart';

/// Token storage 实现选择点。
///
/// 当前默认 in-memory，保证 mock RC 与测试确定性。真实联调/上线前改为
/// `FlutterSecureAuthTokenStorage()`（或 flavor 级 override），不要让 feature 直接 new。
final authTokenStorageProvider = Provider<AuthTokenStorage>((ref) {
  return InMemoryAuthTokenStorage();
});
