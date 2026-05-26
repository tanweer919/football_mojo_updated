import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/repositories/global_cup_repository.dart';
import '../widgets/prize_tier_card.dart';

class GlobalCupScreen extends ConsumerWidget {
  const GlobalCupScreen({super.key, required this.tournamentId});
  final String tournamentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboard = ref.watch(globalCupLeaderboardProvider(tournamentId));
    final prizes = ref.watch(globalCupPrizesProvider(tournamentId));
    final me = ref.watch(myCupRankProvider(tournamentId));
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Global Cup'),
          bottom: const TabBar(tabs: [Tab(text: 'Leaderboard'), Tab(text: 'Prizes')]),
        ),
        body: CenteredContent(
          child: Column(
            children: [
              me.maybeWhen(
                data: (rank) => rank.rank == 0
                    ? const SizedBox.shrink()
                    : Container(
                        margin: const EdgeInsets.all(12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: [theme.colorScheme.primaryContainer, theme.colorScheme.surfaceContainerHigh],
                          ),
                        ),
                        child: Row(
                          children: [
                            Text('Your rank',
                                style: theme.textTheme.labelLarge?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer)),
                            const Spacer(),
                            Text('#${rank.rank}',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    fontFeatures: const [FontFeature.tabularFigures()])),
                            const SizedBox(width: 14),
                            Text('${rank.total.toStringAsFixed(1)} pts',
                                style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer)),
                          ],
                        ),
                      ).animate().fade(duration: 320.ms).slideY(begin: 0.05, end: 0),
                orElse: () => const SizedBox.shrink(),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    leaderboard.when(
                      loading: () => const SkeletonList(itemHeight: 56),
                      error: (e, _) => ErrorView(
                          message: '$e',
                          onRetry: () => ref.invalidate(globalCupLeaderboardProvider(tournamentId))),
                      data: (entries) => ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = entries[i];
                          return ListTile(
                            leading: SizedBox(
                              width: 36,
                              child: Text('#${e.rank}',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                            ),
                            title: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundImage: e.photoUrl != null
                                      ? CachedNetworkImageProvider(e.photoUrl!)
                                      : null,
                                  child: e.photoUrl == null ? const Icon(Icons.person, size: 16) : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(e.displayName ?? 'Anonymous',
                                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                            trailing: Text(e.points.toStringAsFixed(0),
                                style: theme.textTheme.titleMedium?.copyWith(
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800)),
                          ).animate().fade(duration: 220.ms, delay: (10 * i.clamp(0, 14)).ms);
                        },
                      ),
                    ),
                    prizes.when(
                      loading: () => const SkeletonList(itemHeight: 110),
                      error: (e, _) => ErrorView(
                          message: '$e',
                          onRetry: () => ref.invalidate(globalCupPrizesProvider(tournamentId))),
                      data: (list) => ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => PrizeTierCard(prize: list[i], indexInList: i),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
