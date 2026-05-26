import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/live_dot.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../competitions/presentation/widgets/competition_chip_selector.dart';
import '../../../scores/presentation/providers/live_matches_provider.dart';
import '../../../scores/presentation/widgets/match_card.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveMatchesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push(RoutePaths.profile),
          ),
        ],
      ),
      body: CenteredContent(
        child: RefreshIndicator(
          onRefresh: () => ref.read(liveMatchesProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverToBoxAdapter(child: CompetitionChipSelector()),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(child: _DailyCard()),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                sliver: SliverToBoxAdapter(child: _PredictionPrompt()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      const LiveDot(size: 8),
                      const SizedBox(width: 8),
                      Text('Live now',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              live.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: SizedBox(height: 320, child: SkeletonList(itemHeight: 96, count: 3)),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: ErrorView(
                    message: '$e',
                    onRetry: () => ref.read(liveMatchesProvider.notifier).refresh(),
                  ),
                ),
                data: (matches) {
                  if (matches.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: EmptyState(
                        icon: Icons.sports_soccer_outlined,
                        title: 'No live matches right now',
                        subtitle: "We'll buzz you the moment something kicks off.",
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                    sliver: SliverList.separated(
                      itemCount: matches.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => MatchCard(match: matches[i], indexInList: i),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {/* TODO claimDailyLogin → animated card-flip */},
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primaryContainer,
              theme.colorScheme.tertiaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.card_giftcard, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's sticker",
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Claim your free player card',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    ).animate().fade(duration: 320.ms, curve: Curves.easeOutCubic).slideY(begin: 0.04, end: 0);
  }
}

class _PredictionPrompt extends StatelessWidget {
  const _PredictionPrompt();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainerHigh,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Icon(Icons.psychology_alt_outlined, color: theme.colorScheme.primary),
        title: const Text('Predict today’s matches'),
        subtitle: const Text('Earn coins, cards, and climb the leaderboard'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {/* TODO push predictions screen */},
      ),
    ).animate().fade(duration: 320.ms, delay: 80.ms).slideY(begin: 0.04, end: 0);
  }
}
