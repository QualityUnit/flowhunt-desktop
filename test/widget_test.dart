import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flowhunt_desktop/main.dart';
import 'package:flowhunt_desktop/screens/onboarding/welcome_screen.dart';

void main() {
  testWidgets('App launches with welcome screen', (WidgetTester tester) async {
    // Build our app and trigger a frame
    await tester.pumpWidget(
      const ProviderScope(
        child: FlowHuntApp(),
      ),
    );
    
    await tester.pumpAndSettle();

    // Verify that the welcome screen is displayed
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Welcome to FlowHunt'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('App has correct theme configuration', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FlowHuntApp(),
      ),
    );
    
    await tester.pumpAndSettle();

    // Verify MaterialApp is configured correctly
    final materialApp = tester.widget<MaterialApp>(
      find.byType(MaterialApp).first,
    );
    
    expect(materialApp.title, 'FlowHunt Desktop');
    expect(materialApp.debugShowCheckedModeBanner, false);
    expect(materialApp.theme, isNotNull);
    expect(materialApp.darkTheme, isNotNull);
  });
}
