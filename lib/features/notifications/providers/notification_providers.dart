import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../auth/providers/auth_providers.dart';
import '../services/notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Initializes push notifications when a user is authenticated.
/// Watch this provider near the app root to auto-register FCM tokens.
final notificationInitProvider = FutureProvider<void>((ref) async {
  if (!AppConfig.useFirebase) return;
  final user = ref.watch(currentUserProvider);
  if (user == null) return;
  if (!user.settings.notificationsEnabled) return;

  await ref.read(notificationServiceProvider).init(user.id);
});
