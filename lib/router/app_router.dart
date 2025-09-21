import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/onboarding/welcome_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
        redirect: (context, state) async {
          // Check authentication
          final authService = ref.read(authServiceProvider);
          final isAuthenticated = await authService.isAuthenticated();

          if (!isAuthenticated) {
            return '/login';
          }

          // Fetch user data if authenticated and not already fetched
          final userState = ref.read(userProvider);
          if (userState.user == null && !userState.isLoading) {
            ref.read(userProvider.notifier).fetchUser();
          }

          return null;
        },
      ),
    ],
    redirect: (context, state) async {
      // Global redirect logic
      final authService = ref.read(authServiceProvider);
      final isAuthenticated = await authService.isAuthenticated();
      
      // If authenticated and trying to access auth pages, redirect to home
      if (isAuthenticated &&
          (state.matchedLocation == '/' || state.matchedLocation == '/login')) {
        return '/home';
      }
      
      return null;
    },
  );
});