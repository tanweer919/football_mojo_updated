import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../favourites/favourites_provider.dart';
import '../notifications/fcm_service.dart';
import '../../features/album/data/repositories/album_repository.dart';
import '../../features/fantasy/presentation/providers/fantasy_providers.dart';
import '../../features/h2h/data/h2h_repository.dart';
import '../../features/iap/data/gems_repository.dart';
import '../../features/predictions/data/predictions_repository.dart';
import '../../features/profile/data/profile_repository.dart';

/// Wipe everything tied to the previously signed-in user so the next account
/// starts clean. Called on sign-out AND whenever the auth uid changes (an
/// account switch that doesn't go through the Sign-out button).
///
/// Two kinds of leak to clear:
///   1. Device-local state that isn't keyed per account — followed teams live
///      in SharedPreferences, and FCM topic subscriptions live on the device.
///      Without this the new user inherits the old user's teams + push.
///   2. User-scoped Riverpod caches (cards, profile, gems, bracket, fantasy,
///      h2h, notifications) that otherwise keep serving the old user's data
///      until something happens to invalidate them.
Future<void> clearUserSession(ProviderContainer container) async {
  // 1a. Drop FCM team-topic subscriptions (unsubscribes the tracked set and
  //     resets its tracking), so the device stops receiving the old user's
  //     team push. The new user re-syncs from their own profile on login.
  try {
    await FcmBootstrap.syncTeams(const <String>{});
  } catch (_) {/* best effort */}

  // 1b. Device-local followed teams.
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('favourites.teams');
  } catch (_) {/* best effort */}

  // 2. Invalidate every user-scoped provider so it refetches for the new user
  //    (or resolves empty while signed out). Family providers invalidate all
  //    instances. Keep this list in sync as new per-user providers are added.
  for (final p in <ProviderOrFamily>[
    favouriteTeamsProvider,
    myProfileProvider,
    albumProvider,
    gemBalanceProvider,
    myBracketProvider,
    notificationPrefsProvider,
    inboxProvider,
    unreadNotificationCountProvider,
    h2hListProvider,
    h2hLadderProvider,
    myLineupProvider,
    ownedCardBoostsProvider,
    draftLineupProvider,
    leagueLeaderboardProvider,
  ]) {
    container.invalidate(p);
  }
}
