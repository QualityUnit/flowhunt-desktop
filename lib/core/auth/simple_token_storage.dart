import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'token_storage_interface.dart';

class SimpleTokenStorage implements TokenStorageInterface {
  static const String _tokenExpiryKey = 'token_expiry_time';

  @override
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    int? expiresIn,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(AppConstants.accessTokenKey, accessToken);

    if (refreshToken != null) {
      await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
    }

    // Store expiry time if provided
    if (expiresIn != null) {
      final expiryTime = DateTime.now().add(Duration(seconds: expiresIn));
      await prefs.setInt(_tokenExpiryKey, expiryTime.millisecondsSinceEpoch);
    }
  }

  @override
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.accessTokenKey);
  }

  @override
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.refreshTokenKey);
  }

  @override
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.accessTokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
    await prefs.remove(_tokenExpiryKey);
  }

  @override
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null;
  }

  @override
  Future<bool> isAccessTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryTimeMs = prefs.getInt(_tokenExpiryKey);

    if (expiryTimeMs == null) {
      // If we don't have expiry info, assume it might be expired
      return false;
    }

    final expiryTime = DateTime.fromMillisecondsSinceEpoch(expiryTimeMs);
    // Add a 5-minute buffer to refresh before actual expiry
    final now = DateTime.now().add(const Duration(minutes: 5));

    return now.isAfter(expiryTime);
  }
}