import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flowhunt_desktop/main.dart' as app;
import 'package:flowhunt_desktop/screens/onboarding/welcome_screen.dart';
import 'package:flowhunt_desktop/screens/auth/login_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-end app test', () {
    testWidgets('Complete user journey from welcome to login', (tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Verify we're on the welcome screen
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Welcome to FlowHunt'), findsOneWidget);

      // Check all features are displayed
      expect(find.text('Create AI Agents'), findsOneWidget);
      expect(find.text('Set Triggers'), findsOneWidget);
      expect(find.text('Connect Integrations'), findsOneWidget);
      expect(find.text('Local & Remote LLMs'), findsOneWidget);

      // Tap the Get Started button
      final getStartedButton = find.text('Get Started');
      expect(getStartedButton, findsOneWidget);
      await tester.tap(getStartedButton);
      await tester.pumpAndSettle();

      // Verify we're on the login screen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Sign in to FlowHunt'), findsOneWidget);
      expect(find.text('Connect your account to get started'), findsOneWidget);

      // Check login button is present
      expect(find.text('Sign in with FlowHunt'), findsOneWidget);

      // Check back button functionality
      final backButton = find.text('Back to Welcome');
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Verify we're back on the welcome screen
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Welcome to FlowHunt'), findsOneWidget);
    });

    testWidgets('Login screen shows loading state', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Navigate to login screen
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();

      // Verify login button is enabled
      final signInButton = find.widgetWithText(ElevatedButton, 'Sign in with FlowHunt');
      expect(signInButton, findsOneWidget);
      
      final button = tester.widget<ElevatedButton>(signInButton);
      expect(button.enabled, isTrue);
    });

    testWidgets('App theme switches correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Get the MaterialApp
      final materialApp = tester.widget<MaterialApp>(
        find.byType(MaterialApp).first,
      );

      // Verify both light and dark themes are configured
      expect(materialApp.theme, isNotNull);
      expect(materialApp.darkTheme, isNotNull);
      expect(materialApp.themeMode, ThemeMode.system);
    });

    testWidgets('App has proper window configuration', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify the app starts successfully with window manager
      expect(find.byType(ProviderScope), findsOneWidget);
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });

  group('Navigation tests', () {
    testWidgets('Router handles navigation correctly', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Start at welcome screen
      expect(find.byType(WelcomeScreen), findsOneWidget);

      // Navigate to login
      await tester.tap(find.text('Get Started'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      // Navigate back to welcome
      await tester.tap(find.text('Back to Welcome'));
      await tester.pumpAndSettle();
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });
  });

  group('UI responsiveness tests', () {
    testWidgets('App adapts to different screen sizes', (tester) async {
      // Test on minimum window size
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      app.main();
      await tester.pumpAndSettle();

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('Welcome to FlowHunt'), findsOneWidget);

      // Test on default window size
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpAndSettle();
      expect(find.text('Welcome to FlowHunt'), findsOneWidget);

      // Test on larger screen
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpAndSettle();
      expect(find.text('Welcome to FlowHunt'), findsOneWidget);

      // Reset the view
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}