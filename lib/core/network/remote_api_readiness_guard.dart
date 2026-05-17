import 'package:flutter/foundation.dart';

import '../config/app_environment.dart';
import 'remote_api_module.dart';
import 'remote_api_readiness_report.dart';
import 'remote_api_switches.dart';

/// Remote API 联调前 guard：环境、baseUrl、风险分级与开关组合校验（A8）。
abstract final class RemoteApiReadinessGuard {
  /// 占位/模板 host，禁止作为真实 remote 目标。
  static const placeholderHosts = {
    'dev-api.example.com',
    'staging-api.example.com',
    'api.example.com',
  };

  static RemoteApiReadinessReport validate({
    required AppConfig config,
    required RemoteApiSwitches requested,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final blocked = <RemoteApiModule>[];
    var effective = requested;

    final baseUrlInvalid = _validateApiBaseUrl(
      config.apiBaseUrl,
      config.environment,
      requested.anyEnabled,
      errors,
    );

    if (baseUrlInvalid && requested.anyEnabled) {
      effective = RemoteApiSwitches.allDisabled;
    }

    for (final module in RemoteApiModule.values) {
      if (!requested.isEnabled(module)) {
        continue;
      }

      final allow = _evaluateModule(
        module: module,
        environment: config.environment,
        baseUrlInvalid: baseUrlInvalid,
        errors: errors,
        warnings: warnings,
      );

      if (!allow) {
        effective = effective.withModule(module, false);
        blocked.add(module);
      }
    }

    if (requested.legacyUseRemoteApi && !requested.drama) {
      warnings.add(
        'USE_REMOTE_API is enabled: legacy fallback maps only to drama (USE_REMOTE_DRAMA_API).',
      );
    }

    final enabled = RemoteApiModule.values
        .where(effective.isEnabled)
        .toList(growable: false);

    return RemoteApiReadinessReport(
      environment: config.environment,
      apiBaseUrl: config.apiBaseUrl,
      requested: requested,
      effective: effective,
      enabledModules: enabled,
      blockedModules: blocked,
      warnings: warnings,
      errors: errors,
    );
  }

  /// Debug / 测试：无效组合时抛错，便于 fail-fast。
  static RemoteApiReadinessReport validateOrThrow({
    required AppConfig config,
    required RemoteApiSwitches requested,
  }) {
    final report = validate(config: config, requested: requested);
    if (!report.isValid) {
      throw RemoteApiReadinessException(report);
    }
    return report;
  }

  static bool _validateApiBaseUrl(
    Uri apiBaseUrl,
    AppEnvironment environment,
    bool anyRemoteRequested,
    List<String> errors,
  ) {
    if (!anyRemoteRequested) {
      return false;
    }

    final raw = apiBaseUrl.toString();
    if (raw.contains('<') || raw.contains('staging-host>')) {
      errors.add(
        'API_BASE_URL must be a real staging host, not a placeholder ($raw).',
      );
      return true;
    }

    final host = apiBaseUrl.host.toLowerCase();
    if (host.isEmpty) {
      errors.add(
        'API_BASE_URL is missing or invalid when remote API is enabled.',
      );
      return true;
    }

    if (placeholderHosts.contains(host)) {
      errors.add(
        'API_BASE_URL host "$host" is a template placeholder; set a real server URL.',
      );
      return true;
    }

    if (host.endsWith('.example.com')) {
      errors.add(
        'API_BASE_URL uses example.com placeholder; remote calls are blocked.',
      );
      return true;
    }

    if (environment != AppEnvironment.dev && _isLoopback(host)) {
      errors.add(
        'API_BASE_URL loopback ($host) is only allowed in APP_ENV=dev.',
      );
      return true;
    }

    return false;
  }

  static bool _isLoopback(String host) {
    return host == 'localhost' ||
        host.startsWith('127.') ||
        host == '0.0.0.0' ||
        host == '[::1]';
  }

  static bool _evaluateModule({
    required RemoteApiModule module,
    required AppEnvironment environment,
    required bool baseUrlInvalid,
    required List<String> errors,
    required List<String> warnings,
  }) {
    if (baseUrlInvalid) {
      return false;
    }

    final risk = module.riskLevel;
    final key = module.dartDefineKey;

    switch (risk) {
      case RemoteApiRiskLevel.high:
        errors.add(
          '$key (${module.name}) is high-risk and blocked in all environments until payment/auth verification is ready.',
        );
        return false;

      case RemoteApiRiskLevel.medium:
        return switch (environment) {
          AppEnvironment.prod => () {
            errors.add(
              '$key (${module.name}) is medium-risk and blocked in APP_ENV=prod.',
            );
            return false;
          }(),
          AppEnvironment.staging => () {
            warnings.add(
              '$key (${module.name}) is medium-risk; enable only after auth/guest bootstrap and schema sign-off.',
            );
            return true;
          }(),
          AppEnvironment.dev => () {
            warnings.add(
              '$key (${module.name}) is medium-risk; prefer mock or dry-run harness in dev.',
            );
            return true;
          }(),
        };

      case RemoteApiRiskLevel.low:
        return switch (environment) {
          AppEnvironment.prod => () {
            warnings.add(
              '$key (${module.name}) is enabled in prod; ensure backend SLA and CDN are ready.',
            );
            return true;
          }(),
          AppEnvironment.staging || AppEnvironment.dev => true,
        };
    }
  }
}

/// Guard 校验失败。
class RemoteApiReadinessException implements Exception {
  RemoteApiReadinessException(this.report);

  final RemoteApiReadinessReport report;

  @override
  String toString() {
    return 'RemoteApiReadinessException: ${report.errors.join('; ')}';
  }
}

/// 是否在 debug 模式下对无效 remote 组合 assert。
bool get remoteApiReadinessAssertInDebug {
  return kDebugMode && !kIsWeb;
}
