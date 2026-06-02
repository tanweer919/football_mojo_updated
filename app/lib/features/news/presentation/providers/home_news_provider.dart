import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/profile_repository.dart' show myProfileProvider;
import '../../data/models/news_article.dart';
import '../../data/repositories/news_repository.dart';

/// Home-screen news feed. Differs from the full `newsFeedProvider`:
///   - Tries a team-filtered query first when the user has a followed team,
///     so stories on home are relevant to who they care about.
///   - Falls back to the global feed when the team filter returns nothing
///     (the RSS aggregator doesn't populate `teamIds` on articles today,
///     so the filter currently always returns empty — without fallback
///     followers would see zero news).
///   - Promotes articles with images to the front so the hero slot always
///     has a picture (the branded fallback covers the rest of the list).
final homeNewsProvider = FutureProvider<NewsPage>((ref) async {
  final profile = ref.watch(myProfileProvider).valueOrNull;
  final teamId = profile?.followedTeams.isNotEmpty == true
      ? profile!.followedTeams.first.id
      : null;
  final repo = ref.read(newsRepositoryProvider);

  // Pull a larger window than we'll show so the image-prioritisation sort
  // has room to find images. 12 covers the home hero + up to 6 rows.
  NewsPage page;
  if (teamId != null) {
    // First try: scope to the followed team.
    page = await repo.list(teamId: teamId, limit: 12);
    // Fallback when the team filter returns nothing. Most articles don't
    // carry team IDs yet, so this fallback fires for nearly every user
    // until the RSS aggregator starts tagging by team.
    if (page.items.isEmpty) {
      page = await repo.list(limit: 12);
    }
  } else {
    page = await repo.list(limit: 12);
  }

  final sorted = [...page.items];
  // Stable sort: articles with an image first, recency preserved within
  // each bucket. The home hero never falls back to a blank-image card
  // when at least one imaged article is available.
  sorted.sort((a, b) {
    final aHas = (a.imageUrl != null && a.imageUrl!.isNotEmpty) ? 0 : 1;
    final bHas = (b.imageUrl != null && b.imageUrl!.isNotEmpty) ? 0 : 1;
    if (aHas != bHas) return aHas - bHas;
    return b.publishedAt.compareTo(a.publishedAt);
  });
  return NewsPage(items: sorted, nextCursor: page.nextCursor);
});

/// Relative time formatter — shared so home + reader screens render the
/// same "2h ago" / "just now" string. Kept here to avoid a top-level
/// helper module for one function.
String relativeTime(DateTime when) {
  final now = DateTime.now();
  final diff = now.difference(when.toLocal());
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 365) {
    final weeks = (diff.inDays / 7).floor();
    return '${weeks}w ago';
  }
  return '${(diff.inDays / 365).floor()}y ago';
}
