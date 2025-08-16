class AppConstants {
  // App Info
  static const String appName = 'FlowHunt Desktop';
  static const String appVersion = '1.0.0';
  
  // OAuth Configuration
  static const String authorizationEndpoint = 'https://api.flowhunt.io/oauth/authorize';
  static const String tokenEndpoint = 'https://api.flowhunt.io/oauth/token';
  static const String clientId = 'flowhunt_desktop_client';
  static const String redirectUri = 'http://localhost:8080/callback';
  static const List<String> scopes = ['profile', 'agents', 'integrations'];
  
  // API Configuration
  static const String apiBaseUrl = 'https://api.flowhunt.io';
  static const Duration apiTimeout = Duration(seconds: 30);
  
  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userProfileKey = 'user_profile';
  static const String onboardingCompletedKey = 'onboarding_completed';
  
  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;
  static const double maxContentWidth = 1200.0;
  
  // Window Configuration
  static const double minWindowWidth = 800.0;
  static const double minWindowHeight = 600.0;
  static const double defaultWindowWidth = 1280.0;
  static const double defaultWindowHeight = 800.0;
}