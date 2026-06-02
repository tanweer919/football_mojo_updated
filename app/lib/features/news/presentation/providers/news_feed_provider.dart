import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/profile_repository.dart' show myProfileProvider;
import '../../data/models/news_article.dart';
import '../../data/repositories/news_repository.dart';

class NewsFeedNotifier extends AsyncNotifier<NewsPage> {
  String? _teamId;

  @override
  Future<NewsPage> build() async {
    return ref.read(newsRepositoryProvider).list();
  }

  Future<void> refresh({String? teamId}) async {
    _teamId = teamId;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(newsRepositoryProvider).list(teamId: teamId));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.nextCursor == null) return;
    final next = await ref.read(newsRepositoryProvider)
        .list(cursor: current.nextCursor, teamId: _teamId);
    state = AsyncValue.data(NewsPage(
      items: [...current.items, ...next.items],
      nextCursor: next.nextCursor,
    ));
  }
}

final newsFeedProvider = AsyncNotifierProvider<NewsFeedNotifier, NewsPage>(NewsFeedNotifier.new);

// ─── Following-tab feed ────────────────────────────────────────────────────

/// AsyncNotifier scoped to the user's followed teams (OR-joined). Mirrors
/// NewsFeedNotifier's pagination + refresh shape so the screen can swap
/// the provider per tab without changing its UI code.
///
/// Reads followed-team IDs from `myProfileProvider`. When the user has
/// nothing followed, returns an empty page WITHOUT hitting the network
/// (no point — backend would return everything, which the UI would then
/// render as "Following" — confusing).
class FollowingNewsNotifier extends AsyncNotifier<NewsPage> {
  List<String> _teamIds = const [];

  @override
  Future<NewsPage> build() async {
    final profile = await ref.watch(myProfileProvider.future);
    _teamIds = profile?.followedTeams.map((t) => t.id).toList() ?? const [];
    if (_teamIds.isEmpty) {
      return NewsPage(items: const [], nextCursor: null);
    }
    return ref.read(newsRepositoryProvider).list(teamIds: _teamIds);
  }

  Future<void> refresh() async {
    if (_teamIds.isEmpty) {
      state = AsyncValue.data(NewsPage(items: const [], nextCursor: null));
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(newsRepositoryProvider).list(teamIds: _teamIds),
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.nextCursor == null) return;
    if (_teamIds.isEmpty) return;
    final next = await ref.read(newsRepositoryProvider).list(
      cursor: current.nextCursor,
      teamIds: _teamIds,
    );
    state = AsyncValue.data(NewsPage(
      items: [...current.items, ...next.items],
      nextCursor: next.nextCursor,
    ));
  }
}

final followingNewsProvider =
    AsyncNotifierProvider<FollowingNewsNotifier, NewsPage>(FollowingNewsNotifier.new);
