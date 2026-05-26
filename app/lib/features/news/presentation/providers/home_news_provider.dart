import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/profile_repository.dart' show myProfileProvider;
import '../../data/models/news_article.dart';
import '../../data/repositories/news_repository.dart';

/// Home-screen news feed. Differs from the full `newsFeedProvider`:
///   - Filters by the user's first followed team when one exists, so the
///     stories on home are relevant to who they actually care about.
///   - Promotes articles with images to the front so the hero slot always
///     has a picture (the branded fallback covers the rest of the list).
///   - Falls back silently to the global feed when no team is followed.
final homeNewsProvider = FutureProvider<NewsPage>((ref) async {
  // Read the profile to derive a team filter. Don't *block* on profile —
  // anonymous users still see news, just unfiltered.
  final profile = ref.watch(myProfileProvider).valueOrNull;
  final teamId = profile?.followedTeams.isNotEmpty == true
      ? profile!.followedTeams.first.id
      : null;

  // Pull a larger window than we'll show so the image-prioritization sort
  // has room to find images. Default 8 is enough for the home top-3 slot.
  final repo = ref.read(newsRepositoryProvider);
  final page = await repo.list(teamId: teamId, limit: 8);

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
