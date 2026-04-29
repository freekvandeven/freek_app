import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final onboardingProvider = AsyncNotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

class OnboardingNotifier extends AsyncNotifier<bool> {
  static const _key = 'onboarding_complete';

  @override
  Future<bool> build() async {
    final prefs = SharedPreferencesAsync();
    return await prefs.getBool(_key) ?? false;
  }

  Future<void> markComplete() async {
    await SharedPreferencesAsync().setBool(_key, true);
    state = const AsyncData(true);
  }
}
