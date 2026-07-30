import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/home_repository_provider.dart';
import '../domain/vip_only_drama.dart';

/// 在同一会员页面展示期间共享会员专享短剧请求结果。
///
/// 每次进入会员相关页面时由页面调用 [Ref.invalidate] 重新拉取，避免长期复用过期数据。
final vipOnlyDramasProvider = FutureProvider<VipOnlyDramaCollection>((ref) {
  return ref.watch(homeRepositoryProvider).getVipOnlyDramas();
});
