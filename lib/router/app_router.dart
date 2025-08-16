import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/dashboard/dashboard_screen.dart';
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
        path: '/dashboard',
        builder: (context, state) => const DashboardScreen(),
        redirect: (context, state) async {
          // Check authentication
          final authService = ref.read(authServiceProvider);
          final isAuthenticated = await authService.isAuthenticated();
          
          if (!isAuthenticated) {
            return '/login';
          }
          return null;
        },
      ),
    ],
    redirect: (context, state) async {
      // Global redirect logic
      final authService = ref.read(authServiceProvider);
      final isAuthenticated = await authService.isAuthenticated();
      
      // If authenticated and trying to access auth pages, redirect to dashboard
      if (isAuthenticated && 
          (state.matchedLocation == '/' || state.matchedLocation == '/login')) {
        return '/dashboard';
      }
      
      return null;
    },
  );
});