import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bare-bones FCM setup. Topic subscriptions are managed by [FcmService.syncTeams].
class FcmBootstrap {
  static const _kRegisteredTokenKey = 'fcm.registered.token';

  /// One Android channel per category. Importance is deliberate:
  ///   - high       for time-sensitive moments (goals, FT, kickoff, 1v1)
  ///   - default    for content that can wait (digest, news, fantasy)
  ///   - low        for cosmetic / promotional (card drops)
  /// iOS has no channel concept — the system handles category-level
  /// controls via the permission request above.
  static const _channels = <AndroidNotificationChannel>[
    AndroidNotificationChannel('mojo.match',   'Match updates',
        description: 'Goals, kickoffs, full time, lineups.',
        importance: Importance.high),
    AndroidNotificationChannel('mojo.h2h',     '1v1 challenges',
        description: 'Invite accepts and head-to-head results.',
        importance: Importance.high),
    AndroidNotificationChannel('mojo.fantasy', 'Fantasy results',
        description: 'Your rank when the gameweek scores.',
        importance: Importance.defaultImportance),
    AndroidNotificationChannel('mojo.news',    'News & recaps',
        description: 'Breaking stories and the daily World Cup digest.',
        importance: Importance.defaultImportance),
    AndroidNotificationChannel('mojo.cards',   'Card drops',
        description: 'New stage editions opening in the store.',
        importance: Importance.low),
  ];

  /// Map the backend's `category` data field to an Android channel.
  /// Falls through to the high-importance match channel — safer to
  /// over-notify on an unknown category than to swallow it silently.
  static AndroidNotificationChannel _channelForCategory(String? category) {
    String id;
    switch (category) {
      case 'h2hInvites':
      case 'h2hResults':
        id = 'mojo.h2h';
        break;
      case 'fantasyResults':
        id = 'mojo.fantasy';
        break;
      case 'breakingNews':
      case 'wcDailyRecap':
        id = 'mojo.news';
        break;
      case 'cardDrops':
        id = 'mojo.cards';
        break;
      default:
        id = 'mojo.match';
    }
    return _channels.firstWhere((c) => c.id == id, orElse: () => _channels.first);
  }

  static final _local = FlutterLocalNotificationsPlugin();

  static Future<void> initialise() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    await _local.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final channel in _channels) {
      await androidPlugin?.createNotificationChannel(channel);
    }

    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      final channel = _channelForCategory(msg.data['category']);
      _local.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
            priority: _priorityFor(channel.importance),
            importance: channel.importance,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });
  }

  static Priority _priorityFor(Importance i) {
    if (i == Importance.high || i == Importance.max) return Priority.high;
    if (i == Importance.low || i == Importance.min) return Priority.low;
    return Priority.defaultPriority;
  }

  /// Request permission and register the user's current FCM token with the
  /// server so per-user push (H2H invite accepts, 1v1 results, etc.) can
  /// land. Idempotent — re-posts on rotation, skips no-op when the token
  /// hasn't changed since last sync.
  ///
  /// Set `force` to true to re-register even when the token hasn't changed
  /// (useful right after sign-in to make sure the *current* account owns it).
  static Future<void> ensureRegistered(Dio dio, {bool force = false}) async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true, badge: true, sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    String? token;
    try {
      token = await FirebaseMessaging.instance.getToken();
    } catch (e) {
      if (kDebugMode) debugPrint('FCM getToken failed: $e');
      return;
    }
    if (token == null || token.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(_kRegisteredTokenKey);
    if (!force && previous == token) return;

    try {
      await dio.post('/v1/users/me/fcm-tokens', data: {'token': token});
      await prefs.setString(_kRegisteredTokenKey, token);
      if (kDebugMode) debugPrint('FCM token registered (${token.substring(0, 8)}…)');
    } catch (e) {
      // Best-effort. We can retry on the next H2H screen visit or app
      // resume — losing one register call is fine.
      if (kDebugMode) debugPrint('FCM register failed: $e');
    }

    // Register for token-refresh events so rotations re-post automatically.
    FirebaseMessaging.instance.onTokenRefresh.listen((next) async {
      try {
        await dio.post('/v1/users/me/fcm-tokens', data: {'token': next});
        await prefs.setString(_kRegisteredTokenKey, next);
      } catch (_) {}
    });
  }

  /// Wire push-tap deeplinks. Call once at app boot with a closure that
  /// performs the actual navigation — typically
  /// `(loc) => ref.read(appRouterProvider).go(loc)`.
  ///
  /// Handles three cases:
  ///   - Cold start from a notification (`getInitialMessage`).
  ///   - App resumed from background by a notification (`onMessageOpenedApp`).
  ///   - The in-app local notification path is not deeplinked — those are
  ///     foreground toasts; the user can tap the actual feature surface.
  ///
  /// Expects the push payload's `data` to carry `deepLink` in the form
  /// `footballmojo://<path>`. Anything else is ignored silently.
  static void installNotificationTaps(void Function(String location) onTap) {
    Future<void> handle(RemoteMessage? msg) async {
      if (msg == null) return;
      final link = msg.data['deepLink'];
      if (link is! String || link.isEmpty) return;
      // Convert `footballmojo://h2h` → `/h2h`. Anything that doesn't match
      // our app scheme is dropped — defence against malformed pushes.
      const prefix = 'footballmojo://';
      if (!link.startsWith(prefix)) return;
      final path = '/${link.substring(prefix.length)}';
      try {
        onTap(path);
      } catch (e) {
        if (kDebugMode) debugPrint('deeplink route failed for $path: $e');
      }
    }

    // Background → foreground.
    FirebaseMessaging.onMessageOpenedApp.listen(handle);
    // Cold start. Fire-and-forget — we don't want to block boot on this.
    FirebaseMessaging.instance.getInitialMessage().then(handle);
  }

  /// Reconciles topic subscriptions with the favourite team set.
  /// Idempotent — safe to call any time favourites change.
  static Future<void> syncTeams(Set<String> teamIds) async {
    final prefs = await SharedPreferences.getInstance();
    final previous = (prefs.getStringList('fcm.subscribed.teams') ?? const []).toSet();
    final toAdd = teamIds.difference(previous);
    final toRemove = previous.difference(teamIds);

    for (final id in toAdd)    await FirebaseMessaging.instance.subscribeToTopic('team_$id');
    for (final id in toRemove) await FirebaseMessaging.instance.unsubscribeFromTopic('team_$id');

    await prefs.setStringList('fcm.subscribed.teams', teamIds.toList());
    if (kDebugMode) debugPrint('FCM teams synced: +$toAdd  -$toRemove');
  }

  /// Subscribe to the country-supporter push topic. Unsubscribes the
  /// previously-supported country first so the user only hears from one.
  static Future<void> syncSupportedCountry(String? countryCode) async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'fcm.subscribed.country';
    final previous = prefs.getString(key);
    if (previous == countryCode) return;
    if (previous != null && previous.isNotEmpty) {
      await FirebaseMessaging.instance.unsubscribeFromTopic('country_$previous');
    }
    if (countryCode != null && countryCode.isNotEmpty) {
      await FirebaseMessaging.instance.subscribeToTopic('country_$countryCode');
    }
    await prefs.setString(key, countryCode ?? '');
  }

  /// Subscribe to the breaking-news topic. Backend pushes are gated by
  /// user preference; topic membership here is the device-level opt-in.
  static Future<void> setBreakingNewsSubscription(bool wantsIt) async {
    if (wantsIt) {
      await FirebaseMessaging.instance.subscribeToTopic('news_breaking');
    } else {
      await FirebaseMessaging.instance.unsubscribeFromTopic('news_breaking');
    }
  }

  /// Subscribe to the WC daily recap topic that matches the device's
  /// current timezone band. Each band fires once at ~09:00 local.
  static Future<void> setWcDigestSubscription(bool wantsIt) async {
    final band = _timezoneBand();
    final all = ['wc_digest_asia', 'wc_digest_europe', 'wc_digest_americas'];
    for (final t in all) {
      if (wantsIt && t == band) {
        await FirebaseMessaging.instance.subscribeToTopic(t);
      } else {
        // Always clear non-matching bands so a user travelling between
        // continents stops getting yesterday's region.
        await FirebaseMessaging.instance.unsubscribeFromTopic(t);
      }
    }
  }

  /// Bucket the device into one of three roughly-09:00-local regions
  /// based on UTC offset. Not perfect (no Pacific) but good enough for
  /// daily recap delivery — better than UTC-only.
  static String _timezoneBand() {
    final off = DateTime.now().timeZoneOffset.inMinutes;
    if (off >= 0 && off < 6 * 60) return 'wc_digest_europe';
    if (off >= 6 * 60) return 'wc_digest_asia';
    return 'wc_digest_americas';
  }
}
