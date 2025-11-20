import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dio/dio.dart';
import 'package:flowhunt_desktop/core/auth/auth_service.dart';
import 'package:flowhunt_desktop/core/auth/token_storage_interface.dart';

class MockDio extends Mock implements Dio {}
class MockTokenStorage extends Mock implements TokenStorageInterface {}
class MockResponse extends Mock implements Response {}

void main() {
  late AuthService authService;
  late MockDio mockDio;
  late MockTokenStorage mockTokenStorage;

  setUp(() {
    mockDio = MockDio();
    mockTokenStorage = MockTokenStorage();
    authService = AuthService(
      dio: mockDio,
      tokenStorage: mockTokenStorage,
    );
  });

  group('AuthService', () {
    group('isAuthenticated', () {
      test('returns true when access token exists', () async {
        when(() => mockTokenStorage.getAccessToken())
            .thenAnswer((_) async => 'valid_token');

        final result = await authService.isAuthenticated();

        expect(result, true);
        verify(() => mockTokenStorage.getAccessToken()).called(1);
      });

      test('returns false when access token is null', () async {
        when(() => mockTokenStorage.getAccessToken())
            .thenAnswer((_) async => null);

        final result = await authService.isAuthenticated();

        expect(result, false);
        verify(() => mockTokenStorage.getAccessToken()).called(1);
      });
    });

    group('refreshToken', () {
      test('refreshes token successfully', () async {
        const refreshToken = 'refresh_token';
        const newAccessToken = 'new_access_token';
        
        when(() => mockTokenStorage.getRefreshToken())
            .thenAnswer((_) async => refreshToken);
        
        final mockResponse = MockResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.data).thenReturn({
          'access_token': newAccessToken,
          'refresh_token': refreshToken,
        });
        
        when(() => mockDio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenAnswer((_) async => mockResponse);
        
        when(() => mockTokenStorage.saveTokens(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
        )).thenAnswer((_) async => {});

        final result = await authService.refreshToken();

        expect(result, true);
        verify(() => mockTokenStorage.getRefreshToken()).called(1);
        verify(() => mockTokenStorage.saveTokens(
          accessToken: newAccessToken,
          refreshToken: refreshToken,
        )).called(1);
      });

      test('returns false when refresh token is null', () async {
        when(() => mockTokenStorage.getRefreshToken())
            .thenAnswer((_) async => null);

        final result = await authService.refreshToken();

        expect(result, false);
        verify(() => mockTokenStorage.getRefreshToken()).called(1);
      });

      test('returns false when refresh fails', () async {
        const refreshToken = 'refresh_token';
        
        when(() => mockTokenStorage.getRefreshToken())
            .thenAnswer((_) async => refreshToken);
        
        when(() => mockDio.post(
          any(),
          data: any(named: 'data'),
          options: any(named: 'options'),
        )).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
          error: 'Network error',
        ));

        final result = await authService.refreshToken();

        expect(result, false);
      });
    });

    group('signOut', () {
      test('clears tokens on sign out', () async {
        when(() => mockTokenStorage.clearTokens())
            .thenAnswer((_) async => {});

        await authService.signOut();

        verify(() => mockTokenStorage.clearTokens()).called(1);
      });
    });

    group('getAccessToken', () {
      test('returns access token from storage', () async {
        const token = 'access_token';
        when(() => mockTokenStorage.getAccessToken())
            .thenAnswer((_) async => token);

        final result = await authService.getAccessToken();

        expect(result, token);
        verify(() => mockTokenStorage.getAccessToken()).called(1);
      });
    });
  });
}