enum AppEnvironment { dev, staging, prod }

class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  static final current = AppConfig.forEnvironment(_environmentFromDefine);

  static AppConfig forEnvironment(AppEnvironment environment) {
    return switch (environment) {
      AppEnvironment.dev => AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse('https://dev-api.example.com'),
      ),
      AppEnvironment.staging => AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse('https://staging-api.example.com'),
      ),
      AppEnvironment.prod => AppConfig(
        environment: environment,
        apiBaseUrl: Uri.parse('https://api.example.com'),
      ),
    };
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
