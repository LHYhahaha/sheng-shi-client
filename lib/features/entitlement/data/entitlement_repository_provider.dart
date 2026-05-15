import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entitlement_repository.dart';
import 'mock_entitlement_repository.dart';

/// Entitlement repository provider。
///
/// 当前默认使用 mock repository。真实 API 接入时，只替换这里的实现即可；UI、
/// Controller 和 Player 不应该直接 new mock 或远程 repository。
final entitlementRepositoryProvider = Provider<EntitlementRepository>((ref) {
  return MockEntitlementRepository.loggedInNonMemberEnoughCoinsAutoOff();
});
