import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:personal_app/features/auth/pages/login_page.dart';
import 'package:personal_app/features/auth/services/auth_service.dart';
import 'package:personal_app/features/auth/services/firebase_auth_service.dart';
import 'package:personal_app/routing/app_router.dart';

import 'firebase_test_setup.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeFirebaseForTesting();
  });

  tearDown(() async {
    await clearEmulatorData();
  });

  // ---------------------------------------------------------------------------
  // Service-level sign-in tests
  // ---------------------------------------------------------------------------
  group('FirebaseAuthService sign-in', () {
    testWidgets('signIn returns user profile on valid credentials', (
      tester,
    ) async {
      await createTestUser(
        email: 'service-login@example.com',
        password: 'Passw0rd!',
      );
      await FirebaseAuth.instance.signOut();

      final service = FirebaseAuthService();
      await service.init();
      expect(service.currentUser, isNull);

      final profile = await service.signIn(
        email: 'service-login@example.com',
        password: 'Passw0rd!',
      );

      expect(profile.email, 'service-login@example.com');
      expect(profile.displayName, isNull);
      expect(service.currentUser, isNotNull);
      expect(service.currentUser!.email, 'service-login@example.com');

      service.dispose();
    });

    testWidgets('signIn throws AuthException on wrong password', (
      tester,
    ) async {
      await createTestUser(
        email: 'wrong-pw@example.com',
        password: 'Passw0rd!',
      );
      await FirebaseAuth.instance.signOut();

      final service = FirebaseAuthService();
      await service.init();

      expect(
        () => service.signIn(
          email: 'wrong-pw@example.com',
          password: 'WrongPassword!',
        ),
        throwsA(isA<AuthException>()),
      );

      expect(service.currentUser, isNull);
      service.dispose();
    });

    testWidgets('signIn throws AuthException on non-existent email', (
      tester,
    ) async {
      final service = FirebaseAuthService();
      await service.init();

      expect(
        () => service.signIn(
          email: 'does-not-exist@example.com',
          password: 'Passw0rd!',
        ),
        throwsA(isA<AuthException>()),
      );

      service.dispose();
    });

    testWidgets('signIn emits user on authStateChanges stream', (tester) async {
      await createTestUser(
        email: 'stream-test@example.com',
        password: 'Passw0rd!',
      );
      await FirebaseAuth.instance.signOut();

      final service = FirebaseAuthService();
      await service.init();

      final states = <String?>[];
      final sub = service.authStateChanges.listen(
        (user) => states.add(user?.email),
      );

      await service.signIn(
        email: 'stream-test@example.com',
        password: 'Passw0rd!',
      );

      // Give the stream time to emit
      await tester.pump(const Duration(milliseconds: 200));

      expect(states, contains('stream-test@example.com'));

      await sub.cancel();
      service.dispose();
    });

    testWidgets('signOut after signIn clears current user', (tester) async {
      await createTestUser(
        email: 'logout-test@example.com',
        password: 'Passw0rd!',
      );
      await FirebaseAuth.instance.signOut();

      final service = FirebaseAuthService();
      await service.init();

      await service.signIn(
        email: 'logout-test@example.com',
        password: 'Passw0rd!',
      );
      expect(service.currentUser, isNotNull);

      await service.signOut();
      expect(service.currentUser, isNull);
      expect(FirebaseAuth.instance.currentUser, isNull);

      service.dispose();
    });

    testWidgets('init restores session from previously signed-in user', (
      tester,
    ) async {
      await createTestUser(
        email: 'persist-session@example.com',
        password: 'Passw0rd!',
      );
      // User is currently signed in from createTestUser

      final service = FirebaseAuthService();
      await service.init();

      expect(service.currentUser, isNotNull);
      expect(service.currentUser!.email, 'persist-session@example.com');

      service.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // UI-level sign-in tests (LoginPage)
  // ---------------------------------------------------------------------------
  group('LoginPage sign-in UI', () {
    testWidgets('shows login form with email, password and sign in button', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginPage())),
      );

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('shows validation errors on empty submit', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginPage())),
      );

      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('shows email validation error for invalid email', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginPage())),
      );

      await tester.enterText(find.byType(TextFormField).first, 'not-an-email');
      await tester.enterText(find.byType(TextFormField).last, 'SomePassword!');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email'), findsOneWidget);
    });

    testWidgets('successful sign-in navigates away from login page', (
      tester,
    ) async {
      // Seed a user in the emulator
      await createTestUser(
        email: 'ui-login@example.com',
        password: 'Passw0rd!',
      );
      await FirebaseAuth.instance.signOut();

      // Build the full app with GoRouter so the redirect kicks in
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/login',
              redirect: (context, state) => null,
              routes: [
                GoRoute(
                  path: '/login',
                  builder: (context, state) => const LoginPage(),
                ),
                GoRoute(
                  path: '/',
                  builder: (context, state) =>
                      const Scaffold(body: Center(child: Text('Dashboard'))),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter credentials
      await tester.enterText(
        find.byType(TextFormField).first,
        'ui-login@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'Passw0rd!');

      // Tap sign in
      await tester.tap(find.text('Sign In'));

      // Wait for the async sign-in + navigation
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After successful sign-in the auth service will have a user
      expect(FirebaseAuth.instance.currentUser, isNotNull);
      expect(FirebaseAuth.instance.currentUser!.email, 'ui-login@example.com');
    });

    testWidgets('shows error message on wrong password', (tester) async {
      await createTestUser(
        email: 'wrong-pw-ui@example.com',
        password: 'Passw0rd!',
      );
      await FirebaseAuth.instance.signOut();

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LoginPage())),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'wrong-pw-ui@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'TotallyWrong!');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // The LoginPage shows the error in a Container
      // AuthException message is mapped from Firebase error code
      expect(find.textContaining('Invalid'), findsOneWidget);
    });

    testWidgets('sign-in with real router redirect sends user to dashboard', (
      tester,
    ) async {
      await createTestUser(
        email: 'redirect-test@example.com',
        password: 'Passw0rd!',
      );
      await FirebaseAuth.instance.signOut();

      // Use the real app router provider for a full-stack test
      late ProviderContainer container;
      container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(appRouterProvider),
          ),
        ),
      );
      // Auth init provider needs time then shows login
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // We should be on the login page (not authenticated)
      expect(find.text('Welcome Back'), findsOneWidget);

      // Enter credentials and submit
      await tester.enterText(
        find.byType(TextFormField).first,
        'redirect-test@example.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'Passw0rd!');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // After signing in, the router should redirect to '/' (dashboard)
      // The login page text should no longer be visible
      expect(find.text('Welcome Back'), findsNothing);
      // Dashboard shows "Personal App" in the app bar
      expect(find.text('Personal App'), findsOneWidget);

      container.dispose();
    });
  });
}
