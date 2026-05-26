import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Favourite teams (multi). Stored as a list of team ids locally.
/// FCM resubscription happens in [FcmService.syncTeamSubscriptions] on change.
class FavouriteTeamsNotifier extends AsyncNotifier<Set<String>> {
  static const _kKey = 'favourites.teams';

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kKey) ?? const []).toSet();
  }

  Future<void> toggle(String teamId) async {
    final current = state.valueOrNull ?? <String>{};
    final next = {...current};
    next.contains(teamId) ? next.remove(teamId) : next.add(teamId);
    await _persist(next);
  }

  Future<void> add(String teamId) async {
    final next = {...(state.valueOrNull ?? const <String>{}), teamId};
    await _persist(next);
  }

  Future<void> _persist(Set<String> next) async {
    state = AsyncValue.data(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kKey, next.toList());
  }
}

final favouriteTeamsProvider =
    AsyncNotifierProvider<FavouriteTeamsNotifier, Set<String>>(FavouriteTeamsNotifier.new);
