import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/pages/forgot_password_page.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/signup_page.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/dashboard/pages/dashboard_page.dart';
import '../features/more/pages/more_page.dart';
import '../presentation/shell/app_shell.dart';

// Placeholder pages for features not yet built
Widget _placeholder(String title) => Scaffold(
  appBar: AppBar(title: Text(title)),
  body: Center(child: Text('$title — coming soon')),
);

final appRouterProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final loggingIn =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password';

      if (!isAuthenticated && !loggingIn) return '/login';
      if (isAuthenticated && loggingIn) return '/';
      return null;
    },
    routes: [
      // Auth routes (outside shell)
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // Main app with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // Tab 0: Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const DashboardPage(),
              ),
            ],
          ),
          // Tab 1: Tasks
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tasks',
                builder: (context, state) => _placeholder('Tasks'),
              ),
            ],
          ),
          // Tab 2: Calendar
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => _placeholder('Calendar'),
              ),
            ],
          ),
          // Tab 3: Finance
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/finance',
                builder: (context, state) => _placeholder('Finance'),
              ),
            ],
          ),
          // Tab 4: More
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (context, state) => const MorePage(),
              ),
            ],
          ),
        ],
      ),

      // Feature routes (pushed on top of shell)
      GoRoute(
        path: '/recipes',
        builder: (context, state) => _placeholder('Recipes'),
      ),
      GoRoute(
        path: '/passwords',
        builder: (context, state) => _placeholder('Password Vault'),
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => _placeholder('Inventory'),
      ),
      GoRoute(
        path: '/knowledge',
        builder: (context, state) => _placeholder('Knowledge Bank'),
      ),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => _placeholder('Feedback'),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => _placeholder('Settings'),
      ),
    ],
  );
});
