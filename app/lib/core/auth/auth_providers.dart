import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_repository.dart';

/// Stream of the current Firebase user (null if signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// True once the user has gone through onboarding (picked at least one team).
/// Independent of sign-in — onboarding can complete with an anonymous user.
class OnboardingCompleteNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'onboarding.completed';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKey) ?? false;
  }

  Future<void> markCompleted() async {
    state = const AsyncValue.data(true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, true);
  }

  Future<void> reset() async {
    state = const AsyncValue.data(false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kKey);
  }
}

final onboardingCompleteProvider =
    AsyncNotifierProvider<OnboardingCompleteNotifier, bool>(OnboardingCompleteNotifier.new);
