class AppConfig {
  final String baseUrl;
  final String wsUrl;
  final String environment;

  AppConfig({
    required this.baseUrl,
    required this.wsUrl,
    required this.environment,
  });

  /// Local development: connects to Go backend on localhost:8080
  factory AppConfig.local() {
    return AppConfig(
      baseUrl: const String.fromEnvironment('API_URL',
          defaultValue: 'http://localhost:8080/api/v1'),
      wsUrl: const String.fromEnvironment('WS_URL',
          defaultValue: 'ws://localhost:8080/ws'),
      environment: 'local',
    );
  }

  factory AppConfig.dev() {
    return AppConfig(
      baseUrl: 'https://dev-api.miigho.com',
      wsUrl: 'wss://dev-ws.miigho.com',
      environment: 'development',
    );
  }

  factory AppConfig.staging() {
    return AppConfig(
      baseUrl: 'https://staging-api.miigho.com',
      wsUrl: 'wss://staging-ws.miigho.com',
      environment: 'staging',
    );
  }

  factory AppConfig.production() {
    return AppConfig(
      baseUrl: 'https://api.miigho.com',
      wsUrl: 'wss://ws.miigho.com',
      environment: 'production',
    );
  }
}
