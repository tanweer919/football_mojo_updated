import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ad_widgets.dart';
import '../../../../core/deeplink/chottu_link_service.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../profile/data/profile_repository.dart' show myProfileProvider;
import '../../data/models/news_article.dart';
import '../providers/news_feed_provider.dart';
import '../widgets/news_card.dart';

/// News screen with two tabs:
///   - All        — global feed (existing `newsFeedProvider`)
///   - Following  — scoped to the user's followed teams via
///                  `followingNewsProvider`. Empty-state nudges to the
///                  team picker when the user follows nothing.
///
/// Each tab owns its own ScrollController for independent infinite-scroll
/// state — switching tabs shouldn't lose scroll position.
class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});
  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _allScroll = ScrollController();
  final _followingScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _allScroll.addListener(() {
      if (_allScroll.position.pixels >
          _allScroll.position.maxScrollExtent - 600) {
        ref.read(newsFeedProvider.notifier).loadMore();
      }
    });
    _followingScroll.addListener(() {
      if (_followingScroll.position.pixels >
          _followingScroll.position.maxScrollExtent - 600) {
        ref.read(followingNewsProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _allScroll.dispose();
    _followingScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide the Following tab badge count off-screen when zero. Otherwise
    // shows a small dot next to the tab so the user knows there's
    // something there.
    final followedCount = ref
        .watch(myProfileProvider)
        .maybeWhen(
          data: (p) => p?.followedTeams.length ?? 0,
          orElse: () => 0,
        );

    // scrollable: false — the page body owns its own scroll (TabBarView →
    // tab-local ListView per tab). Wrapping the Column-with-Expanded
    // inside PitchScreen's default SingleChildScrollView triggers an
    // unbounded-height assertion because Expanded needs a bounded
    // parent.
    return PitchScreen(
      title: 'News',
      onBack: context.canPop() ? () => context.pop() : null,
      scrollable: false,
      trailing: CircleIconButton(
        icon: Icons.ios_share_rounded,
        onPressed: () => ChottuLinkService.instance.shareApp(),
      ),
      child: Column(
        children: [
          _TabBar(
            controller: _tabs,
            followedCount: followedCount,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _AllFeed(scrollController: _allScroll),
                _FollowingFeed(
                  scrollController: _followingScroll,
                  followedCount: followedCount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab bar ────────────────────────────────────────────────────────────────

class _TabBar extends StatelessWidget {
  const _TabBar({required this.controller, required this.followedCount});
  final TabController controller;
  final int followedCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bg,
      child: TabBar(
        controller: controller,
        labelColor: AppColors.gold,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.gold,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        tabs: [
          const Tab(text: 'ALL'),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('FOLLOWING'),
                if (followedCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$followedCount',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared list renderer ───────────────────────────────────────────────────

/// Renders a NewsPage as a scrollable list with banner ads every 5
/// articles. Used by both tabs — the only difference is which provider
/// feeds it data.
class _NewsList extends StatelessWidget {
  const _NewsList({
    required this.page,
    required this.scrollController,
  });
  final NewsPage page;
  final ScrollController scrollController;

  static const _adInterval = 5;

  @override
  Widget build(BuildContext context) {
    final totalAds = page.items.length ~/ _adInterval;
    final totalItems = page.items.length + totalAds;
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: totalItems,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, i) {
        // Every (adInterval + 1)th slot is an ad.
        final adsBefore = i ~/ (_adInterval + 1);
        final isAdSlot = (i + 1) % (_adInterval + 1) == 0;
        if (isAdSlot) {
          return const PitchBannerAd(
            padding: EdgeInsets.symmetric(vertical: 4),
          );
        }
        final articleIndex = i - adsBefore;
        if (articleIndex >= page.items.length) {
          return const SizedBox.shrink();
        }
        return NewsCard(
          article: page.items[articleIndex],
          indexInList: articleIndex,
        );
      },
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: 4,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const Skeleton(height: 220, radius: 16),
    );
  }
}

// ─── All tab ────────────────────────────────────────────────────────────────

class _AllFeed extends ConsumerWidget {
  const _AllFeed({required this.scrollController});
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(newsFeedProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface3,
      onRefresh: () => ref.read(newsFeedProvider.notifier).refresh(),
      child: feed.when(
        loading: () => const _LoadingList(),
        error: (e, _) => _NewsErrorList(
          error: e,
          onRetry: () => ref.read(newsFeedProvider.notifier).refresh(),
        ),
        data: (page) {
          if (page.items.isEmpty) {
            return _EmptyAll(
              onRetry: () => ref.read(newsFeedProvider.notifier).refresh(),
            );
          }
          return _NewsList(page: page, scrollController: scrollController);
        },
      ),
    );
  }
}

class _EmptyAll extends StatelessWidget {
  const _EmptyAll({required this.onRetry});
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) {
    // ListView so RefreshIndicator's pull-to-refresh still works when the
    // empty state doesn't fill the screen.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 40),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Eyebrow("TODAY'S STORIES", gold: true),
              SizedBox(height: 12),
              Text(
                'No stories yet',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.fg,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Sources update every 10 minutes. Pull to refresh or hit retry.',
                style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GoldButton(label: 'Retry', onPressed: onRetry),
          ),
        ),
      ],
    );
  }
}

/// Error state that's pull-to-refresh-able. Used for both All and
/// Following tabs. Renders the dio/network message so prod users can
/// screenshot and report it instead of seeing a silent blank screen.
class _NewsErrorList extends StatelessWidget {
  const _NewsErrorList({required this.error, required this.onRetry});
  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      children: [
        const Eyebrow('COULDN’T LOAD NEWS', gold: true),
        const SizedBox(height: 12),
        const Text(
          'Something went wrong fetching stories',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.fg,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface3,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Text(
            '$error',
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
              fontSize: 11.5,
              color: AppColors.live,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: GoldButton(label: 'Retry', onPressed: onRetry),
        ),
      ],
    );
  }
}

// ─── Following tab ─────────────────────────────────────────────────────────

class _FollowingFeed extends ConsumerWidget {
  const _FollowingFeed({
    required this.scrollController,
    required this.followedCount,
  });
  final ScrollController scrollController;
  final int followedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No followed teams — surface the picker immediately rather than an
    // empty list. Skips the provider entirely; nothing useful to fetch.
    if (followedCount == 0) {
      return _NoTeamsFollowed();
    }

    final feed = ref.watch(followingNewsProvider);
    return RefreshIndicator(
      color: AppColors.gold,
      backgroundColor: AppColors.surface3,
      onRefresh: () => ref.read(followingNewsProvider.notifier).refresh(),
      child: feed.when(
        loading: () => const _LoadingList(),
        error: (e, _) => _NewsErrorList(
          error: e,
          onRetry: () => ref.read(followingNewsProvider.notifier).refresh(),
        ),
        data: (page) {
          if (page.items.isEmpty) return _NoMatchingArticles();
          return _NewsList(page: page, scrollController: scrollController);
        },
      ),
    );
  }
}

class _NoTeamsFollowed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('FOLLOWING', gold: true),
          const SizedBox(height: 12),
          const Text(
            'Follow a few teams',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.fg,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pick the clubs and national teams you care about — this tab will fill up with stories about them.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          GoldButton(
            label: 'Pick teams',
            onPressed: () => context.push(RoutePaths.teamPicker),
          ),
        ],
      ),
    );
  }
}

class _NoMatchingArticles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      // Use ListView so the RefreshIndicator's pull-to-refresh works
      // even when the empty state takes less than a screen.
      children: const [
        SizedBox(height: 40),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Eyebrow('FOLLOWING', gold: true),
              SizedBox(height: 12),
              Text(
                'No fresh stories yet',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.fg,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'We tag articles as new ones come in. Pull to refresh — sources update every 10 minutes.',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
