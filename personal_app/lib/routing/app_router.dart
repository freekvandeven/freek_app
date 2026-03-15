import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/pages/forgot_password_page.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/signup_page.dart';
import '../features/auth/pages/change_password_page.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/calendar/pages/calendar_page.dart';
import '../features/connections/pages/connections_page.dart';
import '../features/conversations/pages/conversation_edit_page.dart';
import '../features/conversations/pages/conversation_list_page.dart';
import '../features/dashboard/pages/dashboard_page.dart';
import '../features/gemini/pages/gemini_chat_page.dart';
import '../features/inventory/pages/inventory_edit_page.dart';
import '../features/inventory/pages/inventory_list_page.dart';
import '../features/knowledge/pages/knowledge_bank_page.dart';
import '../features/knowledge/pages/knowledge_edit_page.dart';
import '../features/knowledge/pages/knowledge_view_page.dart';
import '../features/feedback/models/feedback_entry.dart';
import '../features/feedback/pages/feedback_edit_page.dart';
import '../features/feedback/pages/feedback_list_page.dart';
import '../features/finances/pages/asset_edit_page.dart';
import '../features/finances/pages/asset_list_page.dart';
import '../features/finances/pages/category_management_page.dart';
import '../features/finances/pages/finance_overview_page.dart';
import '../features/finances/pages/transaction_edit_page.dart';
import '../features/finances/pages/transaction_list_page.dart';
import '../features/more/pages/more_page.dart';
import '../features/passwords/pages/password_detail_page.dart';
import '../features/passwords/pages/password_edit_page.dart';
import '../features/passwords/pages/password_list_page.dart';
import '../features/passwords/pages/vault_unlock_page.dart';
import '../features/passwords/providers/vault_providers.dart';
import '../features/recipes/pages/recipe_detail_page.dart';
import '../features/recipes/pages/recipe_edit_page.dart';
import '../features/recipes/pages/recipe_list_page.dart';
import '../features/changelog/pages/changelog_page.dart';
import '../features/settings/pages/data_export_page.dart';
import '../features/settings/pages/profile_page.dart';
import '../features/settings/pages/settings_page.dart';
import '../features/tasks/pages/task_edit_page.dart';
import '../features/tasks/pages/task_list_page.dart';
import '../presentation/shell/app_shell.dart';

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
                builder: (context, state) => const TaskListPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    builder: (context, state) => const TaskEditPage(),
                  ),
                  GoRoute(
                    path: ':taskId',
                    builder: (context, state) =>
                        TaskEditPage(taskId: state.pathParameters['taskId']),
                  ),
                ],
              ),
            ],
          ),
          // Tab 2: Calendar
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (context, state) => const CalendarPage(),
              ),
            ],
          ),
          // Tab 3: Finance
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/finance',
                builder: (context, state) => const FinanceOverviewPage(),
                routes: [
                  GoRoute(
                    path: 'transactions',
                    builder: (context, state) => const TransactionListPage(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) =>
                            const TransactionEditPage(),
                      ),
                      GoRoute(
                        path: ':transactionId',
                        builder: (context, state) => TransactionEditPage(
                          transactionId: state.pathParameters['transactionId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'assets',
                    builder: (context, state) => const AssetListPage(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const AssetEditPage(),
                      ),
                      GoRoute(
                        path: ':assetId',
                        builder: (context, state) => AssetEditPage(
                          assetId: state.pathParameters['assetId'],
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) => const CategoryManagementPage(),
                  ),
                ],
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
        builder: (context, state) => const RecipeListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const RecipeEditPage(),
          ),
          GoRoute(
            path: ':recipeId',
            builder: (context, state) =>
                RecipeDetailPage(recipeId: state.pathParameters['recipeId']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    RecipeEditPage(recipeId: state.pathParameters['recipeId']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/passwords',
        builder: (context, state) => const VaultUnlockPage(),
        routes: [
          GoRoute(
            path: 'list',
            redirect: (context, state) {
              final isLocked = ref.read(vaultLockedProvider);
              if (isLocked) return '/passwords';
              return null;
            },
            builder: (context, state) => const PasswordListPage(),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const PasswordEditPage(),
              ),
              GoRoute(
                path: ':entryId',
                builder: (context, state) => PasswordDetailPage(
                  entryId: state.pathParameters['entryId']!,
                ),
                routes: [
                  GoRoute(
                    path: 'edit',
                    builder: (context, state) => PasswordEditPage(
                      entryId: state.pathParameters['entryId'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/inventory',
        builder: (context, state) => const InventoryListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const InventoryEditPage(),
          ),
          GoRoute(
            path: ':itemId',
            builder: (context, state) =>
                InventoryEditPage(itemId: state.pathParameters['itemId']),
          ),
        ],
      ),
      GoRoute(
        path: '/knowledge',
        builder: (context, state) => const KnowledgeBankPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const KnowledgeEditPage(),
          ),
          GoRoute(
            path: ':pageId',
            builder: (context, state) =>
                KnowledgeViewPage(pageId: state.pathParameters['pageId']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    KnowledgeEditPage(pageId: state.pathParameters['pageId']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/connections',
        builder: (context, state) => const ConnectionsPage(),
      ),
      GoRoute(
        path: '/gemini',
        builder: (context, state) => const GeminiChatPage(),
      ),
      GoRoute(
        path: '/feedback',
        builder: (context, state) => const FeedbackListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) {
              final typeParam = state.uri.queryParameters['type'];
              FeedbackType? initialType;
              if (typeParam == 'bug') initialType = FeedbackType.bug;
              if (typeParam == 'wish') initialType = FeedbackType.wish;
              return FeedbackEditPage(initialType: initialType);
            },
          ),
          GoRoute(
            path: ':entryId',
            builder: (context, state) =>
                FeedbackEditPage(entryId: state.pathParameters['entryId']),
          ),
        ],
      ),
      GoRoute(
        path: '/conversations',
        builder: (context, state) => const ConversationListPage(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const ConversationEditPage(),
          ),
          GoRoute(
            path: ':topicId',
            builder: (context, state) => ConversationEditPage(
              topicId: state.pathParameters['topicId'],
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
        routes: [
          GoRoute(
            path: 'export',
            builder: (context, state) => const DataExportPage(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: 'changelog',
            builder: (context, state) => const ChangelogPage(),
          ),
          GoRoute(
            path: 'change-password',
            builder: (context, state) => const ChangePasswordPage(),
          ),
        ],
      ),
    ],
  );
});
