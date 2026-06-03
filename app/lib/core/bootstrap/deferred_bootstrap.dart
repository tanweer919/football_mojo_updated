import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ads/admob_service.dart';
import '../analytics/clarity_service.dart';
import '../config/remote_app_config.dart';
import '../deeplink/chottu_link_service.dart';
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

    // CRITICAL: several tasks below register long-lived listeners (FCM taps,
    // ChottuLink deep links, auth-state changes) whose callbacks fire long
    // after this method returns — by which point HomeShell's [ref] may be
    // disposed. Reading a disposed WidgetRef throws ("Cannot use ref after
    // the widget was disposed"), which silently killed deep-link navigation.
    // Use the ROOT ProviderContainer instead: it lives for the whole app, so
    // these callbacks can always read providers.
    final container = ProviderScope.containerOf(context, listen: false);

    // Only spin up AdMob when the remote kill-switch allows it. A slow or
    // failed config fetch defaults to ads-on, so this never silently
    // disables ads on a flaky network.
    Future.microtask(() async {
      final cfg = await container.read(remoteAppConfigProvider.future);
      if (cfg.adsEnabled) await AdmobService.initialise();
    });
    Future.microtask(FcmBootstrap.initialise);
    // Wire push-tap deeplinks to the active GoRouter.
    Future.microtask(() => FcmBootstrap.installNotificationTaps(
          (loc) => container.read(appRouterProvider).go(loc),
        ));
    // Register the device's FCM token with the server every time auth
    // state flips to signed-in. Anonymous users skip — push needs a uid.
    // Also fires when the user already-signed-in app cold-starts, since
    // authStateChanges emits the cached user on first listen.
    Future.microtask(() {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user == null) return;
        FcmBootstrap.ensureRegistered(container.read(dioProvider), force: true);
      });
    });
    Future.microtask(() => _initClarity(context));
    Future.microtask(AppUpdatesService.checkAll);
    Future.microtask(inAppUpdateService.check);

    // ChottuLink — deep linking + shareable links.
    Future.microtask(() async {
      await ChottuLinkService.instance.init();
      ChottuLinkService.instance.listenForLinks((rawUrl) {
        final route = ChottuLinkService.instance.parseDeepLink(rawUrl);
        if (route != null) {
          container.read(appRouterProvider).go(route);
        }
      });
    });
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
