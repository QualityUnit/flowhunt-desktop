import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flowhunt_desktop/screens/onboarding/welcome_screen.dart';

void main() {
  group('WelcomeScreen', () {
    late GoRouter router;

    setUp(() {
      router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const WelcomeScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Login Screen')),
            ),
          ),
        ],
      );
    });

    testWidgets('displays welcome text and features', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );

      // Check if welcome text is displayed
      expect(find.text('Welcome to FlowHunt'), findsOneWidget);
      expect(find.text('Create AI Agents and connect them to your stack'), findsOneWidget);

      // Check if feature items are displayed
      expect(find.text('Create AI Agents'), findsOneWidget);
      expect(find.text('Build custom AI agents for your specific needs'), findsOneWidget);
      
      expect(find.text('Set Triggers'), findsOneWidget);
      expect(find.text('Configure when and how your agents run'), findsOneWidget);
      
      expect(find.text('Connect Integrations'), findsOneWidget);
      expect(find.text('Integrate with your existing tools and services'), findsOneWidget);
      
      expect(find.text('Local & Remote LLMs'), findsOneWidget);
      expect(find.text('Use both local and cloud-based language models'), findsOneWidget);

      // Check if Get Started button is displayed
      expect(find.text('Get Started'), findsOneWidget);
    });

    testWidgets('navigates to login screen on Get Started tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );

      // Find and tap the Get Started button
      final getStartedButton = find.text('Get Started');
      expect(getStartedButton, findsOneWidget);
      
      await tester.tap(getStartedButton);
      await tester.pumpAndSettle();

      // Verify navigation to login screen
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('displays feature icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );

      // Check if all feature icons are displayed
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
      expect(find.byIcon(Icons.psychology_outlined), findsOneWidget);
    });

    testWidgets('has proper layout constraints', (tester) async {
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );

      // Find the main card widget
      final card = find.byType(Card);
      expect(card, findsOneWidget);

      // Find the constrained box
      final constrainedBox = find.byType(ConstrainedBox);
      expect(constrainedBox, findsOneWidget);
    });

    testWidgets('renders correctly in different screen sizes', (tester) async {
      // Test on a smaller screen
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );

      expect(find.text('Welcome to FlowHunt'), findsOneWidget);

      // Test on a larger screen
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );

      expect(find.text('Welcome to FlowHunt'), findsOneWidget);

      // Reset the view
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}