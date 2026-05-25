import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../providers/live_matches_provider.dart';
import '../widgets/match_card.dart';

class LiveMatchesScreen extends ConsumerWidget {
  const LiveMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveMatchesProvider);
    final notifier = ref.read(liveMatchesProvider.notifier);

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: live.when(
        loading: () => const SkeletonList(itemHeight: 96),
        error: (err, _) => ErrorView(message: '$err', onRetry: notifier.refresh),
        data: (matches) {
          if (matches.isEmpty) {
            return const EmptyState(
              icon: Icons.sports_soccer_outlined,
              title: 'No live matches right now',
              subtitle: "We'll keep you in sync when kick-off arrives.",
            );
          }
          final cols = context.columnsFor(mobile: 1, tablet: 2, desktop: 3);
          return CenteredContent(
            child: cols == 1
                ? ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    itemCount: matches.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => MatchCard(match: matches[i], indexInList: i),
                  )
                : GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: matches.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 132,
                    ),
                    itemBuilder: (_, i) => MatchCard(match: matches[i], indexInList: i),
                  ),
          );
        },
      ),
    );
  }
}
