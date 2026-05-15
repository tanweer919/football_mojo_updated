import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bare-bones FCM setup. Topic subscriptions are managed by [FcmService.syncTeams].
class FcmBootstrap {
  static const _channel = AndroidNotificationChannel(
    'mojo.match',
    'Match updates',
    description: 'Goals, kickoffs, full time and lineup alerts',
    importance: Importance.high,
  );
  static final _local = FlutterLocalNotificationsPlugin();

  static Future<void> initialise() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    await _local.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (n == null) return;
      _local.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            priority: Priority.high,
            importance: Importance.high,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    });
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
}
