import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'token_storage_interface.dart';

class SimpleTokenStorage implements TokenStorageInterface {
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(AppConstants.accessTokenKey, accessToken);
    
    if (refreshToken != null) {
      await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
    }
  }
  
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.accessTokenKey);
  }
  
  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.refreshTokenKey);
  }
  
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.accessTokenKey);
    await prefs.remove(AppConstants.refreshTokenKey);
  }
  
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null;
  }
}