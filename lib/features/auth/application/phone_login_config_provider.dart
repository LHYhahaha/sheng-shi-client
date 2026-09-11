import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 是否展示手机号登录入口。
///
/// 手机号登录配置接口尚未提供；保留独立 provider 作为唯一开关接入点，避免 UI
/// 在接口上线时再散落条件判断。接口接入后在这里替换为服务端读取即可。
final phoneLoginEnabledProvider = FutureProvider<bool>((ref) async {
  // TODO(real-api): GET /api/config/param?code=phone_login_config
  // 未接入前默认开放，让已有客户端可以使用已完成的本地表单流程。
  return true;
});
