import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/features/auth/pages/login_page.dart';
import 'package:personal_app/features/dashboard/pages/dashboard_page.dart';

void main() {
  testWidgets('Login page shows sign in form', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginPage())),
    );

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('Dashboard page shows feature grid', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: DashboardPage())),
    );

    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Finance'), findsOneWidget);
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Passwords'), findsOneWidget);
  });
}
