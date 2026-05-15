import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/player_recharge_unlock_repository.dart';
import 'mock_player_recharge_unlock_repository.dart';

/// Entitlement 解锁充值弹窗的数据入口。
///
/// 这里和普通 Store/Membership 页面分开，是为了表达“为当前 locked episode 继续解锁”
/// 的上下文。未来真实接口可按 episode、账号权益和地区返回不同组合，不影响 Store 页。
final playerRechargeUnlockRepositoryProvider =
    Provider<PlayerRechargeUnlockRepository>((ref) {
      return const MockPlayerRechargeUnlockRepository();
    });
