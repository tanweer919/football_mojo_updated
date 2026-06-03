# Observability — Sentry + Firebase Analytics

Firebase **Crashlytics** has been removed. Error reporting is now **Sentry**;
product analytics is **Firebase Analytics** (Microsoft Clarity stays as-is for
session replay).

## Sentry (crash / error reporting)

All Sentry access goes through `lib/core/observability/observability_service.dart`
— never import `sentry_flutter` elsewhere.

### What's wired
- `ObservabilityService.init` wraps `runApp` in `main.dart`, installing
  `FlutterError.onError`, `PlatformDispatcher.onError` and an error `Zone` —
  uncaught Dart errors (sync + async + isolate) are captured automatically.
- `SentryNavigatorObserver` on the router → navigation breadcrumbs + screen
  transactions.
- User id/email attached on `authStateChanges` (deferred bootstrap), cleared on
  sign-out. `shorebird_patch` tag distinguishes base-release vs code-push crashes.
- Privacy: `sendDefaultPii = false`, no screenshots, no session replay.
- Debug builds never send events (`beforeSend` drops them).

### Activate it
1. Create a Sentry project (platform: **Flutter**) → copy the DSN.
2. Pass the DSN at build time (add to your existing `--dart-define` list):

   ```bash
   shorebird release android \
     --dart-define=SENTRY_DSN=https://<key>@<org>.ingest.sentry.io/<project>
   ```

   With no `SENTRY_DSN`, Sentry stays disabled but the app behaves identically —
   safe for local dev.

### "Errors map to code" (symbolication)
Release builds are **not obfuscated** (no `--obfuscate` on the `shorebird release`
command), so Flutter AOT stack traces stay human-readable and Sentry
symbolicates Dart frames **with zero symbol upload**. Nothing else to do.

> Optional future hardening — if you ever add `--obfuscate
> --split-debug-info=build/symbols` to `shorebird release` *and* `shorebird
> patch`, Dart frames become unreadable. You'd then add `sentry_dart_plugin`
> (dev dependency) + a gitignored `SENTRY_AUTH_TOKEN`, and run
> `dart run sentry_dart_plugin` after each release/patch to upload symbols.

## Firebase Analytics

Wrapper: `lib/core/analytics/analytics_service.dart` (singleton `analyticsService`).
- Auto `screen_view` via `analyticsService.observer` on the router.
- `setUserId` / `email_domain` user property on auth changes; collection enabled
  in release only.
- Instrumented events: `login`, `sign_up`, `gem_purchase`, `card_claim`,
  `fantasy_submit`. Add more with `analyticsService.logEvent(name, params)`.

No extra console setup needed beyond the existing `google-services.json` /
`GoogleService-Info.plist`. Verify events in Firebase **DebugView** during dev
(`adb shell setprop debug.firebase.analytics.app com.footballmojo`).
