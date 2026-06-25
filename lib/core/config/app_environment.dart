/// 应用运行环境。
///
/// 环境只影响 baseUrl 等基础配置，不应在业务代码里用环境分支绕过状态机或权限判断。
enum AppEnvironment { dev, staging, prod }

/// 应用级静态配置。
///
/// 当前通过 `--dart-define=APP_ENV` 选择环境，便于测试和打包保持确定性。后续如果接
/// 远程配置，也应该只覆盖可调策略，不要远程改 API host 这类启动前必须稳定的值。
class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  /// 当前环境。
  final AppEnvironment environment;

  /// API base URL。
  ///
  /// 仅网络层使用，业务页面不要根据 URL 判断环境或行为。
  final Uri apiBaseUrl;

  static final current = AppConfig.forEnvironment(_environmentFromDefine);

  static AppConfig forEnvironment(
    AppEnvironment environment, {
    String? apiBaseUrlOverride,
  }) {
    final override = apiBaseUrlOverride ?? _apiBaseUrlOverrideFromDefine;
    if (override != null && override.isNotEmpty) {
      return AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse(override),
      );
    }

    return switch (environment) {
      AppEnvironment.dev => AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse('https://gateway-api.8y4w2vxvdffmd83.xyz'),
        //http://192.168.1.15:8888
      ),
      AppEnvironment.staging => AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse('https://staging-api.example.com'),
      ),
      AppEnvironment.prod => AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse('https://gateway-api.3ype43hnuvw82h67e523.xyz'),
      ),
    };
  }

  static String? get _apiBaseUrlOverrideFromDefine {
    const value = String.fromEnvironment('API_BASE_URL');
    return value.isEmpty ? null : value;
  }

  static AppEnvironment get _environmentFromDefine {
    const value = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

    return switch (value) {
      'prod' => AppEnvironment.prod,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.dev,
    };
  }
}
