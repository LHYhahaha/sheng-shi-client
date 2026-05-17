import '../config/app_environment.dart';
import 'remote_api_module.dart';
import 'remote_api_switches.dart';

/// [RemoteApiReadinessGuard] 校验结果。
class RemoteApiReadinessReport {
  const RemoteApiReadinessReport({
    required this.environment,
    required this.apiBaseUrl,
    required this.requested,
    required this.effective,
    required this.enabledModules,
    required this.blockedModules,
    required this.warnings,
    required this.errors,
  });

  final AppEnvironment environment;
  final Uri apiBaseUrl;
  final RemoteApiSwitches requested;
  final RemoteApiSwitches effective;
  final List<RemoteApiModule> enabledModules;
  final List<RemoteApiModule> blockedModules;
  final List<String> warnings;
  final List<String> errors;

  bool get isValid => errors.isEmpty;

  bool get hasRemoteEnabled => effective.anyEnabled;

  bool isEffective(RemoteApiModule module) => effective.isEnabled(module);
}
