import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_toast_service.dart';

/// 全局 toast 服务入口；Player / Store / Wallet / Membership / Auth 统一使用。
final appToastProvider = Provider<AppToastService>(
  (ref) => const BotAppToastService(),
);
