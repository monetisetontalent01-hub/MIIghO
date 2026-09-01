import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:miigho/core/network/api_client.dart';
import 'package:miigho/core/storage/secure_storage.dart';

class MockHttpAdapter implements HttpClientAdapter {
  final Map<String, ResponseBody Function(RequestOptions options)> handlers = {};

  void register(String path, ResponseBody Function(RequestOptions options) handler) {
    handlers[path] = handler;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    for (final entry in handlers.entries) {
      if (options.path.contains(entry.key)) {
        return entry.value(options);
      }
    }
    return ResponseBody.fromString(
      jsonEncode({'error': 'not found'}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService secureStorage;
  late ApiClient apiClient;
  late MockHttpAdapter adapter;

  setUp(() {
    secureStorage = SecureStorageService.inMemory();
    apiClient = ApiClient('http://localhost:8080/api/v1', secureStorage);
    adapter = MockHttpAdapter();
    apiClient.httpClientAdapter = adapter;
  });

  test('Single 401 triggers refresh and replays original request successfully', () async {
    await secureStorage.saveTokens(
      accessToken: 'old_expired_access_token',
      refreshToken: 'valid_refresh_token',
    );

    int getCallCount = 0;
    adapter.register('/chat/conversations', (options) {
      getCallCount++;
      if (getCallCount == 1) {
        return ResponseBody.fromString(
          jsonEncode({'error': 'unauthorized'}),
          401,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      } else {
        return ResponseBody.fromString(
          jsonEncode({
            'data': [
              {'id': 'conv_1', 'title': 'Test Chat'}
            ]
          }),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      }
    });

    // Mock the refresh call
    adapter.register('/auth/token/refresh', (options) {
      return ResponseBody.fromString(
        jsonEncode({
          'success': true,
          'data': {
            'access_token': 'new_refreshed_access_token',
            'refresh_token': 'new_refreshed_refresh_token',
          }
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    String? refreshedToken;
    apiClient.onTokenRefreshed = (token) {
      refreshedToken = token;
    };

    // Make request that encounters 401
    final response = await apiClient.get('/chat/conversations');
    expect(response.statusCode, 200);
    expect(refreshedToken, 'new_refreshed_access_token');
    expect(await secureStorage.getAccessToken(), 'new_refreshed_access_token');
    expect(await secureStorage.getRefreshToken(), 'new_refreshed_refresh_token');
  });

  test('Concurrent 401s on 3 requests trigger exactly 1 refresh call and all succeed', () async {
    await secureStorage.saveTokens(
      accessToken: 'old_expired_token',
      refreshToken: 'valid_refresh_token',
    );

    int refreshCallCount = 0;
    adapter.register('/auth/token/refresh', (options) {
      refreshCallCount++;
      return ResponseBody.fromString(
        jsonEncode({
          'success': true,
          'data': {
            'access_token': 'concurrent_access_token',
            'refresh_token': 'concurrent_refresh_token',
          }
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    Map<String, int> callCounts = {'/req1': 0, '/req2': 0, '/req3': 0};

    for (final path in ['/req1', '/req2', '/req3']) {
      adapter.register(path, (options) {
        callCounts[path] = (callCounts[path] ?? 0) + 1;
        if (callCounts[path] == 1) {
          return ResponseBody.fromString(
            jsonEncode({'error': 'unauthorized'}),
            401,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'path': path}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });
    }

    // Launch 3 concurrent requests
    final results = await Future.wait([
      apiClient.get('/req1'),
      apiClient.get('/req2'),
      apiClient.get('/req3'),
    ]);

    expect(results.length, 3);
    for (final res in results) {
      expect(res.statusCode, 200);
    }

    // EXACTLY 1 refresh call executed!
    expect(refreshCallCount, 1);
  });

  test('Anti-loop: 401 on /auth/token/refresh does not trigger further refresh', () async {
    await secureStorage.saveTokens(
      accessToken: 'expired_token',
      refreshToken: 'expired_refresh',
    );

    adapter.register('/auth/token/refresh', (options) {
      return ResponseBody.fromString(
        jsonEncode({'error': 'invalid refresh token'}),
        401,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    });

    try {
      await apiClient.post('/auth/token/refresh', data: {'refresh_token': 'expired_refresh'});
    } catch (_) {}

    // Storage is cleared
    expect(await secureStorage.getAccessToken(), isNull);
  });
}
