import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/news_article.dart';
import '../../data/repositories/news_repository.dart';

/// Home-screen "Today's stories" feed — the GLOBAL latest news, shown the
/// same whether or not the user is signed in. (Followed-team headlines have
/// their own home in the "Your teams" section + the News screen's Following
/// tab, so we don't filter here — that made the home feed inconsistent:
/// team-scoped when logged in, global when logged out.)
///
/// Promotes articles with images to the front so the hero slot always has a
/// picture (the branded fallback covers the rest of the list).
final homeNewsProvider = FutureProvider<NewsPage>((ref) async {
  final repo = ref.read(newsRepositoryProvider);
  // Pull a larger window than we'll show so the image-prioritisation sort
  // has room to find images. 12 covers the home hero + up to 6 rows.
  final page = await repo.list(limit: 12);

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
