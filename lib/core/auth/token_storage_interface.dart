abstract class TokenStorageInterface {
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
  });

  Future<String?> getAccessToken();

  Future<String?> getRefreshToken();

  Future<void> clearTokens();

  Future<bool> hasTokens();

  Future<bool> isAccessTokenExpired();
}