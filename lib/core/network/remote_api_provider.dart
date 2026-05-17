import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_environment.dart';
import 'remote_api_readiness_guard.dart';
import 'remote_api_readiness_report.dart';
import 'remote_api_switches.dart';

/// 编译期请求的 remote 开关（未经过 guard）。
final remoteApiSwitchesProvider = Provider<RemoteApiSwitches>(
  (ref) => RemoteApiSwitches.fromEnvironment(),
);

/// 按环境与风险分级计算后的有效开关（fail-closed）。
///
/// Feature repository **默认仍直接读** [RemoteApiSwitches.fromEnvironment]；
/// 联调阶段可改为读取 [remoteApiEffectiveSwitchesProvider] 以强制 guard。
final remoteApiEffectiveSwitchesProvider = Provider<RemoteApiSwitches>((ref) {
  final report = ref.watch(remoteApiReadinessReportProvider);
  return report.effective;
});

/// Remote 联调 readiness 报告（测试、启动日志、staging checklist）。
final remoteApiReadinessReportProvider = Provider<RemoteApiReadinessReport>((
  ref,
) {
  return RemoteApiReadinessGuard.validate(
    config: AppConfig.current,
    requested: ref.watch(remoteApiSwitchesProvider),
  );
});
