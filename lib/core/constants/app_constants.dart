class AppConstants {
  // App Info
  static const String appName = 'FlowHunt Desktop';
  static const String appVersion = '1.0.0';

  // API Configuration
  static const String apiBaseUrl = 'https://api.flowhunt.io/v2';
  static const Duration apiTimeout = Duration(seconds: 30);

  // OAuth Configuration
  static const String authorizationEndpoint = '$apiBaseUrl/auth/oauth/authorize';
  static const String tokenEndpoint = '$apiBaseUrl/auth/oauth/token';
  static const String clientId = 'flowhunt_desktop_client';
  static const String clientType = 'desktop_native'; // Explicitly identify as desktop app
  
  // Dynamic port configuration for OAuth redirect
  static const List<int> redirectPorts = [8080, 8081, 8082, 3000, 3001, 9090, 9091];
  static const String redirectHost = 'localhost'; // More reliable than localhost
  static const String redirectPath = '/callback';
  
  // This will be set dynamically when starting auth
  static String getRedirectUri(int port) => 'http://$redirectHost:$port$redirectPath';
  
  static const List<String> scopes = ['profile', 'agents', 'integrations'];
  

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