import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart';
import 'core/observability/observability_service.dart';

/// Hard rule: anything `await`-ed here delays the first frame. Only put work
/// here that's required to render the splash-replacement frame correctly.
///
/// Deferred to first frame (via [runDeferredBootstrap] in HomeShell):
///   AdMob init, FCM bootstrap + permission ask, Clarity, in-app update,
///   Shorebird patch check, Remote Config gate.
///
/// Splash budget:
///   - The native (Android 12+ / iOS) launch screen renders BEFORE Flutter
///     starts. We retain it via flutter_native_splash so the user never sees
///     a white flash between OS splash and Flutter splash.
///   - First frame fires at runApp(). FlutterNativeSplash.remove() is called
///     from FootballMojoApp.initState after that.
Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);

  // Fire-and-forget — orientation lock doesn't gate the first frame.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Edge-to-edge so the system nav bar doesn't paint a black band over the
  // gradient backgrounds in our Pitch screens. Combined with `Scaffold`'s
  // background colour painting under the system bars, the gesture pill /
  // 3-button bar now floats on top of our content seamlessly.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Parallelise: Hive (local cache) and Firebase init are independent.
  // Cutting from serial ~250ms to ~max(50, 200) ≈ 200ms.
  await Future.wait([
    Hive.initFlutter(),
    _initFirebase(),
  ]);

  // Wrap runApp so Sentry installs FlutterError.onError,
  // PlatformDispatcher.onError and an error Zone BEFORE the first frame —
  // this is the only thing that must run here rather than in the deferred
  // bootstrap, because it has to be in place to catch startup + async errors.
  await ObservabilityService.init(
    appRunner: () => runApp(const ProviderScope(child: FootballMojoApp())),
  );
}

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (e, st) {
    // Tolerate missing Firebase config in dev — the rest of the app still boots.
    if (kDebugMode) debugPrint('Firebase init skipped: $e\n$st');
  }
}
