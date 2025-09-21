import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../sdk/api_client.dart';
import '../sdk/models/user.dart';
import '../sdk/services/user_service.dart';
import 'auth_provider.dart';

// Provider for UserService
final userServiceProvider = Provider<UserService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return UserService(apiClient: apiClient);
});

// State class for user data
class UserState {
  final UserResponse? user;
  final bool isLoading;
  final String? error;

  UserState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  UserState copyWith({
    UserResponse? user,
    bool? isLoading,
    String? error,
  }) {
    return UserState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// State notifier for managing user data
class UserNotifier extends StateNotifier<UserState> {
  final UserService _userService;
  final Ref _ref;

  UserNotifier(this._userService, this._ref) : super(UserState());

  Future<void> fetchUser() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _userService.getCurrentUser();
      state = state.copyWith(user: user, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateProfile({
    String? username,
    String? avatarUrl,
  }) async {
    if (state.user == null) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedUser = await _userService.updateProfile(
        username: username,
        avatarUrl: avatarUrl,
      );
      state = state.copyWith(user: updatedUser, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clear() {
    state = UserState();
  }
}

// Provider for user state
final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  final userService = ref.watch(userServiceProvider);
  return UserNotifier(userService, ref);
});

// Provider for API client with auth
final apiClientProvider = Provider<FlowHuntApiClient>((ref) {
  final authService = ref.watch(authServiceProvider);
  return FlowHuntApiClient(authService: authService);
});