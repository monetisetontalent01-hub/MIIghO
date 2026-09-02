import 'package:flutter_test/flutter_test.dart';
import 'package:miigho/core/config/app_config.dart';

void main() {
  group('AppConfig Tests', () {
    test('AppConfig.local() points to localhost:8080 by default', () {
      final config = AppConfig.local();
      expect(config.baseUrl, 'http://localhost:8080/api/v1');
      expect(config.wsUrl, 'ws://localhost:8080/ws');
      expect(config.environment, 'local');
    });

    test('AppConfig.fromEnvironment() in test/debug mode defaults to local development', () {
      final config = AppConfig.fromEnvironment();
      expect(config.baseUrl, 'http://localhost:8080/api/v1');
      expect(config.wsUrl, 'ws://localhost:8080/ws');
      expect(config.environment, 'local');
    });

    test('AppConfig.production() requires explicit URLs', () {
      final config = AppConfig.production(
        baseUrl: 'https://api.miigho.com/api/v1',
        wsUrl: 'wss://api.miigho.com/ws',
      );
      expect(config.baseUrl, 'https://api.miigho.com/api/v1');
      expect(config.wsUrl, 'wss://api.miigho.com/ws');
      expect(config.environment, 'production');
    });

    test('AppConfig.dev() has development URLs', () {
      final config = AppConfig.dev();
      expect(config.baseUrl, 'https://dev-api.miigho.com');
      expect(config.wsUrl, 'wss://dev-ws.miigho.com');
      expect(config.environment, 'development');
    });

    test('AppConfig.staging() has staging URLs', () {
      final config = AppConfig.staging();
      expect(config.baseUrl, 'https://staging-api.miigho.com');
      expect(config.wsUrl, 'wss://staging-ws.miigho.com');
      expect(config.environment, 'staging');
    });
  });
}
