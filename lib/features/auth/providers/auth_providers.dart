import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../config/app_config.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/firebase_auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  if (AppConfig.useFirebase) {
    final service = FirebaseAuthService();
    ref.onDispose(() => service.dispose());
    return service;
  }
  final service = MockAuthService(SharedPreferencesAsync());
  ref.onDispose(() => service.dispose());
  return service;
});

final authInitProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(authServiceProvider);
  await service.init();
});

final authStateProvider = StreamProvider<UserProfile?>((ref) {
  final service = ref.watch(authServiceProvider);
  // Emit current user immediately, then listen for changes.
  return Stream.value(
    service.currentUser,
  ).concatWith([service.authStateChanges]);
});

final currentUserProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

extension _StreamConcat<T> on Stream<T> {
  Stream<T> concatWith(Iterable<Stream<T>> others) async* {
    yield* this;
    for (final stream in others) {
      yield* stream;
    }
  }
}
