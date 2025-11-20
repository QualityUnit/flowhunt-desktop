import 'package:logger/logger.dart';

import '../api_client.dart';
import '../models/user.dart';

class UserService {
  final FlowHuntApiClient _apiClient;
  final Logger _logger = Logger();

  UserService({
    required FlowHuntApiClient apiClient,
  }) : _apiClient = apiClient;

  /// Fetch the current authenticated user's details
  Future<UserResponse> getCurrentUser() async {
    try {
      _logger.d('Fetching current user details');
      final response = await _apiClient.get<Map<String, dynamic>>('/auth/me');
      final user = UserResponse.fromJson(response);
      _logger.i('Successfully fetched user: ${user.email}');
      return user;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to fetch current user',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Update the current user's profile
  Future<UserResponse> updateProfile({
    String? username,
    String? avatarUrl,
  }) async {
    try {
      _logger.d('Updating user profile');
      if (username != null) _logger.d('New username: $username');
      if (avatarUrl != null) _logger.d('New avatar URL: $avatarUrl');

      final data = <String, dynamic>{};
      if (username != null) data['username'] = username;
      if (avatarUrl != null) data['avatar_url'] = avatarUrl;

      final response = await _apiClient.put<Map<String, dynamic>>(
        '/auth/me',
        data: data,
      );

      final user = UserResponse.fromJson(response);
      _logger.i('Successfully updated user profile: ${user.email}');
      return user;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to update user profile',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}