# App updates + analytics bootstrap

The mobile boot is split into two phases for fast splash:

| Phase | Lives in | Runs |
|---|---|---|
| **Critical** | `main()` | Firebase init · FCM bootstrap · AdMob init · Hive · theme. Blocks `runApp`. |
| **Deferred** | [`core/bootstrap/deferred_bootstrap.dart`](../bootstrap/deferred_bootstrap.dart) | Fires from `HomeShell.initState` via `addPostFrameCallback`. Clarity, Shorebird patch check, Play Store in-app update, FCM topic sync. Fire-and-forget — splash is never blocked. |

## Update sources, ranked cheapest first

| Layer | Trigger | UI surface | Owner |
|---|---|---|---|
| **Shorebird** (cross-platform) | `shorebird patch …` | Slim Flutter banner: "Update ready — restart to apply" | [`AppUpdatesService`](app_updates_service.dart) |
| **Play Store in-app update** (Android) | New release with priority set in Play Console | **Native Play UI** — flexible banner or immediate full-screen. *No Flutter UI.* | [`InAppUpdateService`](in_app_update_service.dart) |
| **Remote Config recommended** (iOS only) | `recommended_version_ios` in Firebase RC | Slim Flutter banner with App Store CTA | [`AppUpdatesService`](app_updates_service.dart) |
| **Remote Config force** (cross-platform) | `min_required_version_*` in Firebase RC | Full-screen blocking `ForceUpdateGate` | [`AppUpdatesService`](app_updates_service.dart) |

Android "recommended" updates intentionally have **no Flutter UI** — Play's native banner is better than anything we'd build. The Flutter banner only renders for:
- Shorebird patch ready (any platform)
- iOS recommended (since App Store has no native equivalent)

## Shorebird setup (one-time)

```bash
curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash
shorebird login
# Run init inside app/ — the Flutter module lives there after the
# app/ + backend/ restructure (this is NOT the repo root).
cd /Users/gb11/Documents/flutter/FootballMojo/app
shorebird init
```

`shorebird init` creates `app/shorebird.yaml` (with the app_id) and registers
it under `flutter.assets` in `app/pubspec.yaml`. Commit both. Build/patch
commands must also be run from `app/`.

## Release & patch

```bash
# Release: replaces `flutter build`. Shorebird tracks this binary.
shorebird release android
shorebird release ios

# Patch: Dart-only delta over the active release.
shorebird patch android
shorebird patch ios
```

**Patches CANNOT contain:** new plugin versions, native code changes, new permissions, asset bundle changes, Dart SDK version changes. Those need a store release.

## Firebase Remote Config keys

| Key | Type | Purpose |
|---|---|---|
| `min_required_version_android` | string (semver) | Below this → blocking force-update screen |
| `min_required_version_ios` | string (semver) | Same, for iOS |
| `recommended_version_ios` | string (semver) | iOS-only banner; Android uses native Play UI |
| `force_update_message` | string | Shown on the force screen |

Empty string = gate disabled.

## Play Console: in-app update priority

Set per-release via Play Developer API:

```
PATCH /edits/{editId}/tracks/production
{
  "track": "production",
  "releases": [{ "versionCodes": [N], "inAppUpdatePriority": 5 }]
}
```

`>= 5` → immediate (full-screen blocking) update. `0–4` → flexible (background download with native banner). Our [`InAppUpdateService`](in_app_update_service.dart) chooses immediate vs flexible based on this value.

## Microsoft Clarity (session recordings + heatmaps)

1. Create a project at https://clarity.microsoft.com — copy the Project ID.
2. Pass it as a Dart compile-time const at build time:

```bash
flutter run --dart-define=CLARITY_PROJECT_ID=YOUR_ID …
flutter build apk --dart-define=CLARITY_PROJECT_ID=YOUR_ID …
```

3. The `ClarityRouteObserver` is registered on `GoRouter.observers` so every navigation auto-tags the session with a screen name. Custom events can be sent via:

```dart
import '../bootstrap/deferred_bootstrap.dart';
clarityService.sendCustomEvent('fantasy.lineup.submit');
clarityService.setTag('competition', competitionId);
```

Clarity user identity is set automatically when Firebase Auth state changes (see `_attachClarityIdentity` in `deferred_bootstrap.dart`).

**Privacy:** Clarity is skipped in `kDebugMode`. If `CLARITY_PROJECT_ID` is empty (e.g. local dev), init is a no-op. Pause recording on privacy-sensitive screens via `clarityService.pause()` / `.resume()`.

## When to use what

| Change | Use |
|---|---|
| Animation polish, copy tweak, bug fix in Dart | **Shorebird patch** |
| New plugin, native code change | Store release |
| Critical bug — every user must update | Store release + bump `min_required_version_*` |
| Soft prompt users to a new version | Bump `inAppUpdatePriority` (Android) / `recommended_version_ios` (iOS) |
| Tracking new user behaviour | Clarity custom event |
