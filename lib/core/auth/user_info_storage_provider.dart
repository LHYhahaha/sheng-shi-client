import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'in_memory_user_info_storage.dart';
import 'user_info_storage.dart';

final userInfoStorageProvider = Provider<UserInfoStorage>((ref) {
  // 当前默认使用内存存储。真实阶段可根据平台替换为 secure storage 或本地数据库。
  return InMemoryUserInfoStorage();
});
