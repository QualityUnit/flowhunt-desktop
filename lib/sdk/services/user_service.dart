import '../../core/auth/auth_service.dart';
import '../api_client.dart';
import '../models/user.dart';

class UserService {
  final FlowHuntApiClient _apiClient;

  UserService({
    required FlowHuntApiClient apiClient,
  }) : _apiClient = apiClient;

  /// Fetch the current authenticated user's details
  Future<UserResponse> getCurrentUser() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/auth/me');
    return UserResponse.fromJson(response);
  }

  /// Update the current user's profile
  Future<UserResponse> updateProfile({
    String? username,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;

    final response = await _apiClient.put<Map<String, dynamic>>(
      '/auth/me',
      data: data,
    );
    return UserResponse.fromJson(response);
  }
}