import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Single entry-point for crash/error reporting (Sentry). Nothing else in the
/// app should import `sentry_flutter` directly — go through this wrapper so the
/// backend stays swappable and every call is no-op-safe.
///
/// ## Why this lives in `main()` and not the deferred bootstrap
/// [init] installs `FlutterError.onError`, `PlatformDispatcher.instance.onError`
/// and an error `Zone` (via Sentry's `appRunner`). Those MUST wrap `runApp` to
/// catch errors thrown during the first frame and in async gaps — they can't be
/// deferred. The init itself is lightweight; all heavy/optional wiring
/// (user identity, breadcrumbs, analytics, patch tag) stays in the deferred
/// bootstrap.
///
/// ## Symbolication ("errors map to code")
/// Release builds are NOT obfuscated (the `shorebird release` command passes no
/// `--obfuscate`), so Flutter AOT stack traces stay human-readable and Sentry
/// symbolicates Dart frames automatically — no symbol upload, no auth token.
/// If obfuscation is ever enabled, add `sentry_dart_plugin` and run
/// `dart run sentry_dart_plugin` after each `shorebird release`/`patch`.
class ObservabilityService {
  ObservabilityService._();

  /// DSN is injected at build time:
  ///   --dart-define=SENTRY_DSN=https://...ingest.sentry.io/...
  /// Empty (e.g. local dev) => Sentry stays disabled but error handlers are
  /// still installed, so the app behaves identically with or without it.
  static const String _dsn = String.fromEnvironment('SENTRY_DSN');

  /// Optional override; otherwise derived from the build mode.
  static const String _environmentOverride =
      String.fromEnvironment('ENVIRONMENT');

  static bool get isEnabled => _dsn.isNotEmpty;

  static String get _environment {
    if (_environmentOverride.isNotEmpty) return _environmentOverride;
    return kReleaseMode ? 'production' : 'development';
  }

  /// Wraps [appRunner] (which calls `runApp`) so Sentry can capture errors from
  /// the very first frame onward. Safe to call with an empty DSN.
  static Future<void> init({required FutureOr<void> Function() appRunner}) {
    return SentryFlutter.init(
      (options) {
        options.dsn = _dsn;
        options.environment = _environment;
        // Release is auto-detected from the platform package info
        // (e.g. com.footballmojo@2.0.0+10).

        // Performance tracing — sample heavily in dev, lightly in prod.
        options.tracesSampleRate = kReleaseMode ? 0.2 : 1.0;
        options.enableAutoSessionTracking = true;

        // Privacy: this is a privacy-conscious product. Never auto-attach PII
        // or screenshots (they can leak sensitive content). View-hierarchy
        // attach is left at its default (off).
        options.sendDefaultPii = false;
        options.attachScreenshot = false;

        options.debug = kDebugMode;

        // Don't ship events from local debug runs into the prod project, even
        // if a DSN is present in the environment.
        options.beforeSend = (event, hint) => kDebugMode ? null : event;
      },
      appRunner: appRunner,
    );
  }

  /// Report a caught error with its stack trace.
  static Future<void> captureException(
    Object error,
    StackTrace? stackTrace, {
    String? hint,
  }) async {
    try {
      await Sentry.captureException(
        error,
        stackTrace: stackTrace,
        hint: hint == null ? null : Hint.withMap({'description': hint}),
      );
    } catch (_) {/* reporting must never throw */}
  }

  static Future<void> captureMessage(
    String message, {
    SentryLevel level = SentryLevel.info,
  }) async {
    try {
      await Sentry.captureMessage(message, level: level);
    } catch (_) {}
  }

  static void addBreadcrumb(
    String message, {
    String? category,
    Map<String, dynamic>? data,
  }) {
    try {
      Sentry.addBreadcrumb(
        Breadcrumb(message: message, category: category, data: data),
      );
    } catch (_) {}
  }

  /// Attach the signed-in user to subsequent events. Pass nothing for [email]
  /// to keep it off the event (PII-minimal by default).
  static void setUser({required String uid, String? email}) {
    try {
      Sentry.configureScope(
        (scope) => scope.setUser(SentryUser(id: uid, email: email)),
      );
    } catch (_) {}
  }

  static void clearUser() {
    try {
      Sentry.configureScope((scope) => scope.setUser(null));
    } catch (_) {}
  }

  static void setTag(String key, String value) {
    try {
      Sentry.configureScope((scope) => scope.setTag(key, value));
    } catch (_) {}
  }
}
