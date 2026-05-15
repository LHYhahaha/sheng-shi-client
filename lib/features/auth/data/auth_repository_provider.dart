import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import 'mock_auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  // Auth repository 统一注入，后续接设备登录、Google/Facebook SDK 或服务端 token
  // 时不需要改页面。页面不要直接调用平台 SDK。
  return MockAuthRepository();
});
