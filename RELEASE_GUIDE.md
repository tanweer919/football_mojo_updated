# Football Mojo — Play Store Release Guide

End-to-end guide to ship the Android app (with Shorebird code-push) and the
backend. Everything below is specific to **this** repo.

- **App name:** Football Mojo
- **Package / applicationId:** `com.footballmojo`
- **Current version:** `1.0.2+4` (versionName `1.0.2`, versionCode `4`) — in `app/pubspec.yaml`
- **Flutter module:** `app/`  ·  **Backend:** `backend/`
- **Firebase project:** `football-mojo`
- **Shorebird app_id:** `1e164bca-547e-4eee-9ba6-541d2b2d0c40` (already in `app/shorebird.yaml`)

> Run every Flutter/Shorebird command from inside **`app/`** (the Flutter module lives there, not the repo root).

---

## 0. Pre-flight: toolchain version alignment ⚠️

`app/pubspec.yaml` requires `flutter: ">=3.40.0"`. Shorebird ships its **own** pinned
Flutter (currently 3.38.5). A `shorebird release` runs `pub get` with Shorebird's
Flutter — if that's **older** than the pubspec constraint, the build fails.

Before releasing, make them consistent — do ONE of:
- `shorebird upgrade` (gets a Shorebird build whose Flutter ≥ 3.40), **or**
- lower the constraint in `app/pubspec.yaml` to match your toolchain, e.g. `flutter: ">=3.38.0"`.

Verify: `flutter --version` and `shorebird --version` should both report a Flutter
that satisfies the pubspec constraint.

---

## 1. Config you MUST replace before release

| What | Where | Current value | Action |
|---|---|---|---|
| **AdMob Android App ID** | `app/android/app/build.gradle` (release buildType, `manifestPlaceholders["admobAppId"]`) | `ca-app-pub-3528263454526689~2685435320` | Confirm this is **your** AdMob app ID. (Debug uses Google's test ID — leave it.) |
| **AdMob ad unit IDs** | passed at build time via `--dart-define` (see §4). Defaults are Google **test** units. | test units | Create Banner / Interstitial / Rewarded units in AdMob → pass the real IDs. |
| **ChottuLink** | `app/lib/core/deeplink/chottu_link_service.dart` | key `c_app_0ZaL…`, domain `footballmojo.chottu.link`, base `https://footballmojo.in` | Confirm these are your live ChottuLink dashboard values + that the domain is verified. |
| **Firebase** | `app/android/app/google-services.json` (project `football-mojo`) | present | Add your **release** signing SHA‑1 **and** SHA‑256 to the Firebase Android app (required for Google Sign‑In on release). Re-download `google-services.json` if you add them. |
| **App label** | `app/android/app/src/main/AndroidManifest.xml` (`android:label`) | `Football Mojo` | Final store display name (this is the on-device launcher label). |
| **Version** | `app/pubspec.yaml` (`version:`) | `1.0.2+4` | Bump for each Play upload (versionCode `+N` must increase). |

> Android-only note: the `idYOUR_APP_ID` placeholder in
> `app/lib/core/updates/app_updates_service.dart` is the **iOS** App Store URL for
> the update prompt. Android uses Play's native in-app update, so you can ignore it
> for this release.

---

## 2. Release signing (keystore)

There's **no** `app/android/key.properties` yet (gitignored). The release build
auto-uses the keystore when this file exists, else falls back to debug signing.

**a) Create an upload keystore** (once, keep it FOREVER — losing it locks you out of updates unless you use Play App Signing):

```bash
keytool -genkey -v -keystore ~/footballmojo-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**b) Create `app/android/key.properties`** (do NOT commit it):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/gb11/footballmojo-upload.jks
```

**c) Get the SHA fingerprints** (add both to Firebase for Google Sign-In):

```bash
keytool -list -v -keystore ~/footballmojo-upload.jks -alias upload
```

> Use **Play App Signing** (recommended). Then ALSO add the SHA‑1/SHA‑256 that
> Google generates (Play Console → Release → Setup → App signing) to Firebase,
> since the app users install is re-signed by Google.

---

## 3. AdMob consent / compliance (one-time, console side)

The app already runs the **UMP (User Messaging Platform)** consent flow at startup,
but the form content is configured in the console:

1. AdMob → **Privacy & messaging → GDPR** → create + **publish** a consent message.
2. (Optional) Create a **US states** message.
3. AdMob → ad unit settings → ad content filtering: exclude alcohol, gambling,
   dating, adult, riba-finance (the app also requests `maxAdContentRating: G`).
4. Play Console **Data safety**: declare **Advertising ID** usage (the
   `com.google.android.gms.permission.AD_ID` permission is in the manifest) and link
   your privacy policy URL.

---

## 4. Build & release (Shorebird)

Shorebird wraps `flutter build` and tracks the binary so you can later push
Dart-only patches. **A new store release is required** whenever native code,
plugins, permissions, assets, or the icon/splash change (i.e. everything in this
build) — patches can't carry those.

**a) Log in** (once):

```bash
shorebird login
```

**b) Cut the release AAB** (run in `app/`). Pass your real AdMob unit IDs:

```bash
cd app
shorebird release android \
  --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN \
  --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN \
  --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN
```

- Output AAB: `app/build/app/outputs/bundle/release/app-release.aab`
- Upload that `.aab` to the Play Console.
- If Shorebird complains about the Flutter version, see §0.

> Without the `--dart-define`s the app falls back to Google **test** ad units
> (safe, but no revenue). The `*_IOS` defines are unused for an Android release.

**c) (Optional) Sanity-preview the exact release build on a device:**

```bash
shorebird preview
```

---

## 5. Backend deploy (env vars)

The API/worker run on Dokploy (Postgres + Redis). Set production env from
`backend/.env.production.example`. Keys that matter for this release:

**Core / infra:** `DATABASE_URL`, `REDIS_URL`, `REDIS_PASSWORD`, `POSTGRES_DB`,
`POSTGRES_USER`, `POSTGRES_PASSWORD`, `PORT`, `NODE_ENV=production`,
`CORS_ORIGINS`, `DOKPLOY_NETWORK`.

**Data feeds:** `API_FOOTBALL_KEY`, `API_FOOTBALL_BASE`, `API_FOOTBALL_PROVIDER`,
`API_FOOTBALL_WC_LEAGUE_ID`, `API_FOOTBALL_WC_SEASON`, `POLL_LEAGUE_IDS`,
`NEWS_RSS_FEEDS`, `THESPORTSDB_KEY`.

**Auth/push:** `FIREBASE_SERVICE_ACCOUNT_B64` (base64 of the service-account JSON),
`INTERNAL_API_KEY`.

**Feature flags (this app):**
- `WC_MODE=true` — World Cup home layout. Set `false` after the tournament.
- `ADS_ENABLED=true` — master ad kill-switch. Set `false` to instantly hide all
  ads across every client with no app update (served via `GET /v1/app-config`).
- `ADMOB_SSV_ENABLED=true` — verify AdMob rewarded server-side callbacks (set up
  the SSV callback URL in AdMob to point at your API).

**After deploy, run once** (data the app needs):

```bash
# in backend/ on the server (or via your deploy hook)
npx prisma migrate deploy
npm run seed            # leagues, WC2026 fixtures, card templates, etc.
```

> The card art / blank-card fix relies on `seed:wc-cards` having run so templates
> carry player photos.

---

## 6. Play Console — first submission

1. **Create app** → default language, app name **Football Mojo**, Free, App.
2. **Internal testing** track first → upload the `.aab` → add testers → roll out →
   verify on a real device.
3. **App content** (left nav) — complete ALL:
   - **Privacy policy** URL (host the in-app Privacy text publicly).
   - **Ads** → Yes, contains ads.
   - **Data safety** → declare Advertising ID + any analytics/crash data
     (Firebase Analytics/Crashlytics), Google account info.
   - **Content rating** questionnaire (no gambling — it's a free prediction game
     with virtual gems, no real-money wagering).
   - **Target audience** → 13+ (not directed at children).
   - **Government apps / news / financial features** → as applicable (you do show
     a news aggregator — answer the News declaration honestly).
4. **Store listing** (see §7) + graphics.
5. Promote to **Production** when internal testing looks good.

---

## 7. Store listing copy

**App name (≤30 chars):**
`Football Mojo`

**Short description (≤80 chars):**
`Predict the World Cup, build your fantasy XI, collect cards & follow live scores.`

**Full description (≤4000 chars):**

```
Football Mojo is your all-in-one companion for the 2026 World Cup and the
beautiful game year-round. Predict, play, collect, and follow every kick — all
in one beautifully crafted app.

⚽ WORLD CUP BRACKET PREDICTOR
Call it from the group stage to the final. Drag to order every group, pick the
best third-place qualifiers, then choose a winner for every knockout tie all the
way to the trophy. Save it, share your full prediction as a single graphic, and
climb the global bracket leaderboard as real results roll in.

🧠 FANTASY MANAGER
Build your XI under a budget, pick your captain, and rack up points as your
players perform in real matches. Track your rank gameweek to gameweek.

🃏 COLLECT PLAYER CARDS
Earn and collect rarity-tiered player cards — Common to Iconic. Open your daily
card, win cards from predictions and 1v1s, and admire the holographic detail in
your collection.

📊 LIVE SCORES & FIXTURES
Live scores, lineups, stats and fixtures across the World Cup and top leagues.
Follow your favourite teams and see their matches first.

📰 NEWS THAT FOLLOWS YOUR TEAMS
A clean news feed with an "All" and "Following" view, so the stories about the
teams you care about rise to the top.

💎 GEMS & REWARDS
Earn gems from daily logins, predictions, fantasy finishes and more. Spend them
in the store. Watch the occasional opt-in ad for a free card.

Built for fans, designed to feel premium. No real-money betting — just football,
predictions and bragging rights.

Football data provided by third parties and may be subject to delay.
```

> Graphics you still need to upload: **app icon (512×512)**, **feature graphic
> (1024×500)**, and **at least 2 phone screenshots** (1080×1920 or similar).
> Use the gold ball icon + screenshots of the bracket, collection, live scores.

---

## 8. Release notes (What's new — ≤500 chars)

**v1.0.2:**
```
• Full World Cup 2026 bracket predictor — group stage to final, shareable as one graphic
• Fantasy manager, live scores, and a team-following news feed
• Collect player cards — daily cards, prediction rewards, and a free card for watching an ad
• Gem wallet with daily rewards
• Polish, performance, and bug fixes
```

---

## 9. Patching after release (Shorebird)

For **Dart-only** changes (logic, UI, copy — no new plugins/native/assets/permissions),
ship instantly without a Play review:

```bash
cd app
shorebird patch android
```

Useful:
```bash
shorebird releases list          # see tracked releases
shorebird patches list           # see pushed patches
shorebird preview                # run a release/patch on a device
```

The app checks for patches on launch + resume (auto-update is on in
`shorebird.yaml`). A patch applies on the **next** cold start.

**A patch is NOT allowed for:** dependency/plugin changes, native (Android) code,
new permissions, asset/icon/splash changes, or Dart SDK bumps — those need a fresh
`shorebird release android` + a new Play upload (bump the version first).

---

## 10. Pre-submission checklist

- [ ] §0 Flutter version aligned (pubspec ↔ Shorebird).
- [ ] `key.properties` created; release build signs with the upload keystore.
- [ ] Release SHA‑1 + SHA‑256 added to Firebase; `google-services.json` current.
- [ ] Real AdMob app ID in `build.gradle`; real ad unit IDs passed via `--dart-define`.
- [ ] AdMob GDPR consent message **published**; ad content filters set.
- [ ] ChottuLink key/domain live and verified.
- [ ] Backend deployed; `prisma migrate deploy` + `seed` run; `WC_MODE`,
      `ADS_ENABLED`, `ADMOB_SSV_ENABLED` set; `/v1/app-config` returns expected flags.
- [ ] Version bumped in `pubspec.yaml`.
- [ ] `shorebird release android … --dart-define=…` produced the `.aab`.
- [ ] Tested on a real device via Internal Testing.
- [ ] Play Console: Data safety, Content rating, Target audience, Ads, Privacy
      policy, News declaration all completed.
- [ ] Store listing copy + icon + feature graphic + screenshots uploaded.
```
