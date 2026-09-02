import 'package:flutter/foundation.dart';

class AppConfig {
  final String baseUrl;
  final String wsUrl;
  final String environment;

  AppConfig({
    required this.baseUrl,
    required this.wsUrl,
    required this.environment,
  });

  /// Factory loading configuration from environment variables (--dart-define).
  /// In Release mode (kReleaseMode), API_URL and WS_URL MUST be explicitly provided via --dart-define.
  /// Absence of either variable in Release mode throws an explicit StateError.
  /// In Debug / Test mode, defaults safely to local development (localhost:8080).
  factory AppConfig.fromEnvironment() {
    const apiUrl = String.fromEnvironment('API_URL');
    const wsUrl = String.fromEnvironment('WS_URL');
    const env = String.fromEnvironment('ENVIRONMENT');

    if (kReleaseMode) {
      if (apiUrl.isEmpty || wsUrl.isEmpty) {
        throw StateError(
          'RELEASE CONFIGURATION ERROR: Both --dart-define=API_URL=... and '
          '--dart-define=WS_URL=... must be explicitly provided at build time. '
          'Implicit fallbacks to localhost or unverified endpoints are strictly forbidden in Release mode.',
        );
      }
      return AppConfig(
        baseUrl: apiUrl,
        wsUrl: wsUrl,
        environment: env.isNotEmpty ? env : 'production',
      );
    }

    // Debug / Test mode: fallback to localhost is permitted for local development
    return AppConfig(
      baseUrl: apiUrl.isNotEmpty ? apiUrl : 'http://localhost:8080/api/v1',
      wsUrl: wsUrl.isNotEmpty ? wsUrl : 'ws://localhost:8080/ws',
      environment: env.isNotEmpty ? env : 'local',
    );
  }

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

  factory AppConfig.production({required String baseUrl, required String wsUrl}) {
    return AppConfig(
      baseUrl: baseUrl,
      wsUrl: wsUrl,
      environment: 'production',
    );
  }
}

