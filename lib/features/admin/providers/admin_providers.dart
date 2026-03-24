import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/admin_service.dart';

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService();
});

final isAdminProvider = FutureProvider<bool>((ref) {
  return ref.read(adminServiceProvider).isAdmin;
});
