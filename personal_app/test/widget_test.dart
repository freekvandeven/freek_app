import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/presentation/pages/home_page.dart';

void main() {
  testWidgets('Home page shows welcome message', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: HomePage())),
    );

    expect(find.text('Welcome to Personal App'), findsOneWidget);
    expect(find.text('Your all-in-one life management app'), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
  });
}
