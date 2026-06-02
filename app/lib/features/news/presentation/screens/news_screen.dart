import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/ad_widgets.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../../core/widgets/skeleton.dart';
import '../providers/news_feed_provider.dart';
import '../widgets/news_card.dart';

class NewsScreen extends ConsumerStatefulWidget {
  const NewsScreen({super.key});
  @override
  ConsumerState<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends ConsumerState<NewsScreen> {
  final _ctrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (_ctrl.position.pixels > _ctrl.position.maxScrollExtent - 600) {
        ref.read(newsFeedProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(newsFeedProvider);
    return PitchScreen(
      title: 'News',
      onBack: context.canPop() ? () => context.pop() : null,
      trailing: CircleIconButton(icon: Icons.search, onPressed: () {}),
      child: RefreshIndicator(
        onRefresh: () => ref.read(newsFeedProvider.notifier).refresh(),
        color: AppColors.gold,
        backgroundColor: AppColors.surface3,
        child: feed.when(
          loading: () => ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, __) => const Skeleton(height: 220, radius: 16),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(20),
            child: Text('$e', style: const TextStyle(color: AppColors.live)),
          ),
          data: (page) {
            if (page.items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Eyebrow('Today\'s Stories', gold: true),
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
                      'Pull to refresh — sources update every 10 minutes.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              );
            }
            // Inject a banner ad every 5 articles.
            final adInterval = 5;
            final totalAds = page.items.length ~/ adInterval;
            final totalItems = page.items.length + totalAds;
            return ListView.separated(
              controller: _ctrl,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: totalItems,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                // Every (adInterval+1)th slot is an ad.
                final adsBefore = adInterval > 0 ? i ~/ (adInterval + 1) : 0;
                final isAdSlot = adInterval > 0 && (i + 1) % (adInterval + 1) == 0;
                if (isAdSlot) {
                  return const PitchBannerAd(
                    padding: EdgeInsets.symmetric(vertical: 4),
                  );
                }
                final articleIndex = i - adsBefore;
                if (articleIndex >= page.items.length) {
                  return const SizedBox.shrink();
                }
                return NewsCard(article: page.items[articleIndex], indexInList: articleIndex);
              },
            );
          },
        ),
      ),
    );
  }
}
