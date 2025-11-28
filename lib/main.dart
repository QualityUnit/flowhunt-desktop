import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/constants/app_constants.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/workspace_provider.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for desktop
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(AppConstants.defaultWindowWidth, AppConstants.defaultWindowHeight),
    minimumSize: Size(AppConstants.minWindowWidth, AppConstants.minWindowHeight),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: AppConstants.appName,
  );

  // Wait for window to be ready before running the app
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    const ProviderScope(
      child: FlowHuntApp(),
    ),
  );

  // Ensure focus after app is running (fixes macOS focus issue)
  Future.delayed(const Duration(milliseconds: 100), () async {
    await windowManager.focus();
  });
}

class FlowHuntApp extends ConsumerStatefulWidget {
  const FlowHuntApp({super.key});

  @override
  ConsumerState<FlowHuntApp> createState() => _FlowHuntAppState();
}

class _FlowHuntAppState extends ConsumerState<FlowHuntApp> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Listen for auth errors and navigate to login
    ref.listen(authErrorProvider, (previous, next) {
      if (next && mounted) {
        // Clear user and workspace data on auth error
        ref.read(userProvider.notifier).clear();
        ref.read(workspaceProvider.notifier).clear();

        // Navigate to login
        router.go('/login');
      }
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
  
  ThemeData _buildLightTheme() {
    const primaryColor = Color(0xFF1E429F); // FlowHunt Blue
    const secondaryColor = Color(0xFF2563EB); // Lighter Blue
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
        brightness: Brightness.light,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
  
  ThemeData _buildDarkTheme() {
    const primaryColor = Color(0xFF1E429F); // FlowHunt Blue
    const secondaryColor = Color(0xFF2563EB); // Lighter Blue
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
        brightness: Brightness.dark,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.defaultRadius),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }
}
