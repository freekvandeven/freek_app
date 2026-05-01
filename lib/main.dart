import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:personal_app/presentation/theme/app_theme.dart';
import 'package:personal_app/routing/app_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'config/app_config.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/notifications/providers/notification_providers.dart';
import 'features/settings/providers/settings_providers.dart';
import 'features/tasks/providers/task_providers.dart';
import 'firebase_options.dart';
import 'presentation/widgets/lock_screen.dart';
import 'services/log_service.dart';
import 'services/widget_service.dart';

Future<void> main() async {
  usePathUrlStrategy();
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await WakelockPlus.enable();
  LogService.instance.install();
  LogService.instance.info('App starting');
  await WidgetService.initialize();

  try {
    await dotenv.load(fileName: 'dotenv');

    if (AppConfig.useFirebase) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      LogService.instance.info('Firebase initialized');

      if (AppConfig.useEmulators) {
        final host = AppConfig.emulatorHost;
        await FirebaseAuth.instance.useAuthEmulator(host, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
        await FirebaseStorage.instance.useStorageEmulator(host, 9199);
        LogService.instance.info('Connected to Firebase emulators at $host');
        if (kDebugMode) {
          debugPrint('🔧 Connected to Firebase emulators at $host');
        }
      }
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Initialization error: $e\n$st');
    }
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to initialize:\n$e',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  runApp(const ProviderScope(child: PersonalApp()));
}

class PersonalApp extends ConsumerWidget {
  const PersonalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authInit = ref.watch(authInitProvider);
    final router = ref.watch(appRouterProvider);

    return authInit.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: ThemeMode.system,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) {
        FlutterNativeSplash.remove();
        LogService.instance.info('Auth init error: $e');
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.darkTheme(),
          themeMode: ThemeMode.system,
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to initialize:\n$e',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => ref.invalidate(authInitProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      data: (_) {
        FlutterNativeSplash.remove();
        final user = ref.watch(currentUserProvider);
        final biometricEnabled = user?.settings.biometricEnabled ?? false;
        final seedColor = ref.watch(customSeedColorProvider);

        // Initialize push notifications when authenticated
        ref.watch(notificationInitProvider);

        // Keep home screen widget in sync with tasks and theme color
        ref.listen(taskListProvider, (_, next) {
          final color = ref.read(customSeedColorProvider);
          next.whenData(
            (tasks) => WidgetService.updateTaskWidget(tasks, seedColor: color),
          );
        });
        ref.listen(customSeedColorProvider, (_, color) {
          final tasks = ref.read(taskListProvider).valueOrNull;
          if (tasks != null) {
            WidgetService.updateTaskWidget(tasks, seedColor: color);
          }
        });

        return MaterialApp.router(
          title: 'Freek App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(seedColor),
          darkTheme: AppTheme.darkTheme(seedColor),
          themeMode: ref.watch(themeModeProvider),
          routerConfig: router,
          builder: (context, child) => LockScreen(
            enabled: biometricEnabled,
            child: child!,
            onSignOut: () => ref.read(authServiceProvider).signOut(),
          ),
        );
      },
    );
  }
}
