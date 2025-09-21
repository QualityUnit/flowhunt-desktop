import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import 'token_storage_interface.dart';

class SimpleTokenStorage implements TokenStorageInterface {
  @override
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
  }
  
  @override
  Future<bool> hasTokens() async {
    final accessToken = await getAccessToken();
    return accessToken != null;
  }
}