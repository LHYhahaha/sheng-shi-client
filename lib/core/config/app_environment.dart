enum AppEnvironment { dev, staging, prod }

class AppConfig {
  const AppConfig({required this.environment, required this.apiBaseUrl});

  final AppEnvironment environment;
  final Uri apiBaseUrl;

  static final current = AppConfig(
    environment: AppEnvironment.dev,
    apiBaseUrl: Uri.parse('https://api.example.com'),
  );
}
