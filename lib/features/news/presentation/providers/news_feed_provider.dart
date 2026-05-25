import 'package:flutter_riverpod/flutter_riverpod.dart';

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
