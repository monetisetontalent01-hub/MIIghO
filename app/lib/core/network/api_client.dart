import 'dart:async';
import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  final String baseUrl;
  final SecureStorageService secureStorage;
  late final Dio dio;
  late final Dio _tokenDio;

  Future<bool>? _refreshFuture;
  void Function(String newToken)? onTokenRefreshed;
  void Function()? onSessionExpired;

  ApiClient(this.baseUrl, this.secureStorage) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    _tokenDio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await secureStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        final statusCode = e.response?.statusCode;
        final path = e.requestOptions.path;
        final isRetry = e.requestOptions.extra['isRetry'] == true;

        final isAuthEndpoint = path.contains('/auth/token/refresh') ||
            path.contains('/auth/otp/') ||
            path.contains('/auth/logout');

        if (statusCode == 401) {
          if (path.contains('/auth/token/refresh')) {
            await secureStorage.clearTokens();
            onSessionExpired?.call();
            return handler.next(e);
          }

          if (!isRetry && !isAuthEndpoint) {
            final success = await _performConcurrentRefresh();
            if (success) {
              try {
                final newToken = await secureStorage.getAccessToken();
                final reqOptions = e.requestOptions;
                reqOptions.headers['Authorization'] = 'Bearer $newToken';
                reqOptions.extra['isRetry'] = true;

                final response = await dio.fetch(reqOptions);
                return handler.resolve(response);
              } catch (err) {
                if (err is DioException) {
                  return handler.next(err);
                }
                return handler.next(e);
              }
            } else {
              onSessionExpired?.call();
              return handler.next(e);
            }
          }
        }
        return handler.next(e);
      },
    ));
    
    dio.interceptors.add(LogInterceptor(responseBody: true, requestBody: true));
  }

  set httpClientAdapter(HttpClientAdapter adapter) {
    dio.httpClientAdapter = adapter;
    _tokenDio.httpClientAdapter = adapter;
  }

  Future<bool> _performConcurrentRefresh() {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }

    _refreshFuture = _executeRefreshToken().whenComplete(() {
      _refreshFuture = null;
    });

    return _refreshFuture!;
  }

  Future<bool> _executeRefreshToken() async {
    final refreshToken = await secureStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      await secureStorage.clearTokens();
      return false;
    }

    try {
      final response = await _tokenDio.post(
        '/auth/token/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final raw = response.data;
        final data = (raw is Map<String, dynamic> && raw.containsKey('data'))
            ? raw['data'] as Map<String, dynamic>
            : raw as Map<String, dynamic>;

        final newAccessToken = data['access_token'] as String?;
        final newRefreshToken = data['refresh_token'] as String?;

        if (newAccessToken != null && newRefreshToken != null) {
          await secureStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );
          onTokenRefreshed?.call(newAccessToken);
          return true;
        }
      }
    } catch (_) {}

    await secureStorage.clearTokens();
    return false;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return dio.patch(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) {
    return dio.delete(path, data: data, queryParameters: queryParameters);
  }
}

