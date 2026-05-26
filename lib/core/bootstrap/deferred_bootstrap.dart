import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/admob_service.dart';
import '../analytics/clarity_service.dart';
import '../network/dio_provider.dart';
import '../notifications/fcm_service.dart';
import '../router/app_router.dart';
import '../updates/app_updates_service.dart';
import '../updates/in_app_update_service.dart';

/// Shared singletons. The `ClarityRouteObserver` is registered on `GoRouter`
/// before init completes; the SDK queues calls until [initialize] succeeds.
final clarityService = ClarityService();
final inAppUpdateService = InAppUpdateService();

final _deferred = _DeferredBootstrap();

/// Call from the first authenticated screen's `addPostFrameCallback`.
/// Idempotent — first call wins, subsequent calls are no-ops.
///
/// Splits app boot into two phases:
///   1. main()           — Firebase init, Hive only (gating the first frame).
///   2. deferred (here)  — AdMob, FCM, Clarity, in-app update, Shorebird patch
///                         check, Remote Config gate.
///
/// Every task runs in its OWN microtask so a slow Clarity init doesn't block
/// AdMob from loading its first banner, etc.
void runDeferredBootstrap(BuildContext context, WidgetRef ref) {
  _deferred.run(context, ref);
}

class _DeferredBootstrap {
  bool _done = false;

  void run(BuildContext context, WidgetRef ref) {
    if (_done) return;
    _done = true;

    Future.microtask(AdmobService.initialise);
    Future.microtask(FcmBootstrap.initialise);
    // Wire push-tap deeplinks to the active GoRouter. Reads the provider
    // lazily inside the closure so the call site can fire before the
    // router instance is built.
    Future.microtask(() => FcmBootstrap.installNotificationTaps(
          (loc) => ref.read(appRouterProvider).go(loc),
        ));
    // Register the device's FCM token with the server every time auth
    // state flips to signed-in. Anonymous users skip — push needs a uid.
    // Also fires when the user already-signed-in app cold-starts, since
    // authStateChanges emits the cached user on first listen.
    Future.microtask(() {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user == null) return;
        FcmBootstrap.ensureRegistered(ref.read(dioProvider), force: true);
      });
    });
    Future.microtask(() => _initClarity(context));
    Future.microtask(AppUpdatesService.checkAll);
    Future.microtask(inAppUpdateService.check);
  }

  Future<void> _initClarity(BuildContext context) async {
    try {
      if (!clarityService.initialize(context)) return;
      _attachClarityIdentity(FirebaseAuth.instance.currentUser);
      FirebaseAuth.instance.authStateChanges().listen(_attachClarityIdentity);
    } catch (e) {
      if (kDebugMode) debugPrint('Deferred: Clarity init failed: $e');
    }
  }

  void _attachClarityIdentity(User? user) {
    if (user == null) {
      clarityService.clearUserIdentity();
      return;
    }
    clarityService.setUserIdentity(userId: user.uid);
    if (user.email != null) clarityService.setTag('email', user.email!);
  }
}
