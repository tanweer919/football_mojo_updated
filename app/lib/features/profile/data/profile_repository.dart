import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'profile_models.dart';

class ProfileRepository {
  ProfileRepository(this._dio);
  final Dio _dio;

  /// Fetches the signed-in user's profile. Returns `null` when:
  ///   - the user isn't authenticated yet (401)
  ///   - the user record hasn't been provisioned server-side (404)
  ///
  /// The screen renders a friendly empty state in both cases.
  Future<Profile?> me() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/users/me');
      return Profile.fromJson(res.data!);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 404) return null;
      rethrow;
    }
  }

  /// Mark the welcome-card reveal as seen on the server so /me stops
  /// returning it. Called after the user dismisses the reveal screen.
  Future<void> dismissWelcomeCard() async {
    try {
      await _dio.post('/v1/users/me/welcome-card/dismiss');
    } on DioException {
      // Non-fatal — server-side state will catch up on next /me read or on
      // a retry after the user reconnects. Don't surface to the UI.
    }
  }

  /// Search users by `@tag` prefix or display name substring. Returns at
  /// most 20 matches. Empty list when `q` is under 2 chars (the backend
  /// enforces that floor).
  Future<List<UserSearchHit>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final res = await _dio.get<List<dynamic>>(
      '/v1/users/search',
      queryParameters: {'q': q},
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(UserSearchHit.fromJson)
        .toList(growable: false);
  }

  /// Set or clear the country the signed-in user supports at the WC.
  /// Pass null to clear.
  Future<String?> setSupportedCountry(String? code) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/v1/users/me/supported-country',
      data: {'supportedCountryCode': code ?? ''},
    );
    return res.data?['supportedCountryCode'] as String?;
  }

  /// Read the user's notification preferences. Always returns a full row
  /// — backend supplies defaults (all-on) when no preference row exists yet.
  Future<NotificationPrefs> notificationPreferences() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/users/me/notification-preferences',
    );
    return NotificationPrefs.fromJson(res.data!);
  }

  /// Patch a partial set of preference flags. Only the keys you pass change.
  Future<NotificationPrefs> setNotificationPreferences(
    Map<String, bool> patch,
  ) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/v1/users/me/notification-preferences',
      data: patch,
    );
    return NotificationPrefs.fromJson(res.data!);
  }
}

/// Per-category notification opt-ins. Mirrors the backend
/// `NotificationPreference` columns 1:1.
class NotificationPrefs {
  NotificationPrefs({
    required this.matchGoals,
    required this.matchKickoff,
    required this.matchFulltime,
    required this.matchLineup,
    required this.breakingNews,
    required this.wcDailyRecap,
    required this.fantasyResults,
    required this.h2hInvites,
    required this.h2hResults,
    required this.cardDrops,
  });
  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
        matchGoals: j['matchGoals'] as bool? ?? true,
        matchKickoff: j['matchKickoff'] as bool? ?? true,
        matchFulltime: j['matchFulltime'] as bool? ?? true,
        matchLineup: j['matchLineup'] as bool? ?? true,
        breakingNews: j['breakingNews'] as bool? ?? true,
        wcDailyRecap: j['wcDailyRecap'] as bool? ?? true,
        fantasyResults: j['fantasyResults'] as bool? ?? true,
        h2hInvites: j['h2hInvites'] as bool? ?? true,
        h2hResults: j['h2hResults'] as bool? ?? true,
        cardDrops: j['cardDrops'] as bool? ?? true,
      );

  final bool matchGoals;
  final bool matchKickoff;
  final bool matchFulltime;
  final bool matchLineup;
  final bool breakingNews;
  final bool wcDailyRecap;
  final bool fantasyResults;
  final bool h2hInvites;
  final bool h2hResults;
  final bool cardDrops;
}

final notificationPrefsProvider = FutureProvider<NotificationPrefs>(
  (ref) => ref.read(profileRepositoryProvider).notificationPreferences(),
);

class UserSearchHit {
  UserSearchHit({
    required this.id,
    this.userTag,
    this.displayName,
    this.photoUrl,
    this.countryCode,
  });
  factory UserSearchHit.fromJson(Map<String, dynamic> j) => UserSearchHit(
        id: j['id'] as String,
        userTag: j['userTag'] as String?,
        displayName: j['displayName'] as String?,
        photoUrl: j['photoUrl'] as String?,
        countryCode: j['countryCode'] as String?,
      );
  final String id;
  final String? userTag;
  final String? displayName;
  final String? photoUrl;
  final String? countryCode;
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(dioProvider));
});

final myProfileProvider = FutureProvider<Profile?>((ref) {
  return ref.read(profileRepositoryProvider).me();
});

// ─── Notification center ────────────────────────────────────────────────────

class InboxItem {
  InboxItem({
    required this.id,
    required this.type,
    required this.sentAt,
    this.category,
    this.title,
    this.body,
    this.deepLink,
    this.readAt,
  });
  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
        id: j['id'] as String,
        type: j['type'] as String? ?? '',
        category: j['category'] as String?,
        title: j['title'] as String?,
        body: j['body'] as String?,
        deepLink: j['deepLink'] as String?,
        sentAt: DateTime.parse(j['sentAt'] as String),
        readAt: j['readAt'] == null ? null : DateTime.parse(j['readAt'] as String),
      );
  final String id;
  final String type;
  final String? category;
  final String? title;
  final String? body;
  final String? deepLink;
  final DateTime sentAt;
  final DateTime? readAt;
  bool get isRead => readAt != null;
}

class InboxPage {
  InboxPage({required this.items, this.nextCursor});
  final List<InboxItem> items;
  final String? nextCursor;
}

/// Extension hangs off the same file so it can reach `_dio`.
extension InboxApi on ProfileRepository {
  Future<InboxPage> inbox({String? cursor, int limit = 30}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/users/me/notifications',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
      },
    );
    return InboxPage(
      items: ((res.data?['items'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(InboxItem.fromJson)
          .toList(growable: false),
      nextCursor: res.data?['nextCursor'] as String?,
    );
  }

  Future<int> unreadCount() async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/users/me/notifications/unread-count',
    );
    return (res.data?['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead({List<String>? ids, bool all = false}) async {
    await _dio.post('/v1/users/me/notifications/read', data: {
      if (all) 'all': true,
      if (!all && ids != null) 'ids': ids,
    });
  }
}

final inboxProvider = FutureProvider<InboxPage>(
  (ref) => ref.read(profileRepositoryProvider).inbox(),
);

final unreadNotificationCountProvider = FutureProvider<int>(
  (ref) => ref.read(profileRepositoryProvider).unreadCount(),
);
