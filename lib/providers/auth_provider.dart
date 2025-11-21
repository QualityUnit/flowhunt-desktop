import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/auth/auth_service.dart';
import '../core/auth/simple_token_storage.dart';
import '../core/auth/token_storage_interface.dart';

// Token Storage Provider - using SimpleTokenStorage for Linux compatibility
final tokenStorageProvider = Provider<TokenStorageInterface>((ref) {
  return SimpleTokenStorage(); // Using SharedPreferences instead of SecureStorage
});

// Dio Provider without auth interceptor to avoid circular dependency
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  return dio;
});

// Dio with Auth Provider - separate provider for authenticated requests
final authenticatedDioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  final tokenStorage = ref.read(tokenStorageProvider);
  
  // Add interceptors for auth headers
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStorage.getAccessToken();
        
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Token expired, try to refresh
          final authService = ref.read(authServiceProvider);
          final refreshed = await authService.refreshToken();
          
          if (refreshed) {
            // Retry the request with new token
            final newToken = await tokenStorage.getAccessToken();
            
            if (newToken != null) {
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              
              try {
                final response = await dio.fetch(error.requestOptions);
                handler.resolve(response);
                return;
              } catch (e) {
                handler.reject(error);
                return;
              }
            }
          }
        }
        
        handler.next(error);
      },
    ),
  );
  
  return dio;
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  final dio = ref.read(dioProvider);
  final tokenStorage = ref.read(tokenStorageProvider);
  
  return AuthService(
    dio: dio,
    tokenStorage: tokenStorage,
  );
});

// Auth State Provider
final authStateProvider = FutureProvider<bool>((ref) async {
  final authService = ref.read(authServiceProvider);
  return await authService.isAuthenticated();
});

// Auth Error Notifier - to trigger navigation to login on auth failures
class AuthErrorNotifier extends StateNotifier<bool> {
  AuthErrorNotifier() : super(false);

  void triggerAuthError() {
    state = true;
    // Reset after triggering
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) state = false;
    });
  }
}

final authErrorProvider = StateNotifierProvider<AuthErrorNotifier, bool>((ref) {
  return AuthErrorNotifier();
});