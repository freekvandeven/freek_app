import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personal_app/presentation/theme/app_theme.dart';
import 'package:personal_app/routing/app_router.dart';

import 'config/app_config.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/settings/providers/settings_providers.dart';
import 'firebase_options.dart';
import 'presentation/widgets/lock_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: 'dotenv');

    if (AppConfig.useFirebase) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('Initialization error: $e\n$st');
    }
    runApp(MaterialApp(
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
    ));
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
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: Text('Failed to initialize: $e'))),
      ),
      data: (_) {
        final user = ref.watch(currentUserProvider);
        final biometricEnabled = user?.settings.biometricEnabled ?? false;

        return MaterialApp.router(
            title: 'Freek App',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ref.watch(themeModeProvider),
            routerConfig: router,
            builder: (context, child) => LockScreen(
              enabled: biometricEnabled,
              child: child!,
            ),
          );
      },
    );
  }
}
