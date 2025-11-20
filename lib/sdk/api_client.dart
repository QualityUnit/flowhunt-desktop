import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../core/constants/app_constants.dart';
import '../core/auth/auth_service.dart';

class FlowHuntApiClient {
  final Dio _dio;
  final AuthService _authService;
  final Logger _logger = Logger();

  FlowHuntApiClient({
    required AuthService authService,
    Dio? dio,
  })  : _authService = authService,
        _dio = dio ?? Dio() {
    _configureDio();
  }

  void _configureDio() {
    _dio.options = BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    // Add auth interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          _logger.d('API Request: ${options.method} ${options.uri}');
          if (options.data != null) {
            _logger.d('Request data: ${options.data}');
          }
          if (options.queryParameters.isNotEmpty) {
            _logger.d('Query parameters: ${options.queryParameters}');
          }

          final token = await _authService.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            _logger.d('Added authorization token to request');
          } else {
            _logger.w('No access token available for request');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.i('API Response: ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}');
          handler.next(response);
        },
        onError: (error, handler) async {
          _logger.e(
            'API Request Error: ${error.requestOptions.method} ${error.requestOptions.uri}',
            error: error,
            stackTrace: error.stackTrace,
          );
          _logger.e('Status Code: ${error.response?.statusCode}');
          _logger.e('Response Data: ${error.response?.data}');

          if (error.response?.statusCode == 401) {
            _logger.w('Received 401 Unauthorized, attempting token refresh...');
            // Try to refresh token
            final refreshed = await _authService.refreshToken();
            if (refreshed) {
              _logger.i('Token refresh successful, retrying request...');
              // Retry the request
              final token = await _authService.getAccessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $token';

              try {
                final response = await _dio.fetch(error.requestOptions);
                _logger.i('Retry successful after token refresh');
                handler.resolve(response);
                return;
              } catch (e) {
                _logger.e('Retry failed after token refresh', error: e);
                handler.reject(error);
                return;
              }
            } else {
              _logger.e('Token refresh failed');
            }
          }
          handler.next(error);
        },
      ),
    );

    // Add logging interceptor in debug mode (disabled for now)
    // _dio.interceptors.add(
    //   LogInterceptor(
    //     request: false,
    //     requestHeader: false,
    //     requestBody: false,
    //     responseHeader: false,
    //     responseBody: false,
    //     error: true,
    //     logPrint: (object) => _logger.d(object.toString()),
    //   ),
    // );
  }

  // Generic GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Generic POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Generic PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Generic DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // Stream for SSE connections
  Stream<String> getStream(
    String path, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async* {
    try {
      final response = await _dio.get<ResponseBody>(
        path,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
          },
        ),
        cancelToken: cancelToken,
      );

      final stream = response.data!.stream;
      await for (final data in stream) {
        final text = utf8.decode(data);
        yield text;
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(DioException error) {
    String message = 'An error occurred';

    _logger.e('Handling API error', error: error);

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;

      _logger.e('Error response - Status: $statusCode, Data: $data');

      if (data is Map<String, dynamic>) {
        // Handle validation errors with detail field
        if (data.containsKey('detail')) {
          final detail = data['detail'];
          if (detail is List && detail.isNotEmpty) {
            // Parse validation error details
            final errors = detail.map((e) => '${e['loc']?.join('.')}: ${e['msg']}').join(', ');
            message = errors;
            _logger.e('Validation errors: $errors');
          } else if (detail is String) {
            message = detail;
            _logger.e('Error detail: $detail');
          }
        } else {
          message = data['message'] ?? data['error'] ?? message;
          _logger.e('Error message: $message');
        }
      } else if (data is String) {
        message = data;
        _logger.e('Error string: $message');
      }

      _logger.e('API Error [$statusCode]: $message');

      switch (statusCode) {
        case 401:
          return UnauthorizedException(message);
        case 403:
          return ForbiddenException(message);
        case 404:
          return NotFoundException(message);
        case 422:
          return ValidationException(message, data);
        case 429:
          return RateLimitException(message);
        case 500:
        case 502:
        case 503:
        case 504:
          return ServerException(message);
        default:
          return ApiException(message, statusCode: statusCode);
      }
    } else if (error.type == DioExceptionType.connectionTimeout ||
               error.type == DioExceptionType.receiveTimeout) {
      _logger.e('Request timeout: ${error.type}');
      return TimeoutException('Request timeout');
    } else if (error.type == DioExceptionType.connectionError) {
      _logger.e('Network connection error: ${error.message}');
      return NetworkException('Network error');
    } else {
      _logger.e('Unknown error type: ${error.type}, Message: ${error.message}');
    }

    return ApiException(message);
  }
}

// Custom exceptions
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException: $message';
}

class UnauthorizedException extends ApiException {
  UnauthorizedException(String message) : super(message, statusCode: 401);
}

class ForbiddenException extends ApiException {
  ForbiddenException(String message) : super(message, statusCode: 403);
}

class NotFoundException extends ApiException {
  NotFoundException(String message) : super(message, statusCode: 404);
}

class ValidationException extends ApiException {
  final dynamic errors;

  ValidationException(String message, this.errors) : super(message, statusCode: 422);
}

class RateLimitException extends ApiException {
  RateLimitException(String message) : super(message, statusCode: 429);
}

class ServerException extends ApiException {
  ServerException(String message) : super(message, statusCode: 500);
}

class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

class TimeoutException extends ApiException {
  TimeoutException(String message) : super(message);
}