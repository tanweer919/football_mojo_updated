import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../providers/fantasy_providers.dart';

class FantasyLeaderboardScreen extends ConsumerWidget {
  const FantasyLeaderboardScreen({super.key, required this.slug, required this.gameweekId});
  final String slug;
  final String gameweekId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lb = ref.watch(leaderboardProvider((slug: slug, gameweekId: gameweekId)));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: CenteredContent(
        child: lb.when(
          loading: () => const SkeletonList(itemHeight: 64),
          error: (e, _) => ErrorView(message: '$e', onRetry: () =>
              ref.invalidate(leaderboardProvider((slug: slug, gameweekId: gameweekId)))),
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
                      backgroundImage: e.photoUrl != null ? CachedNetworkImageProvider(e.photoUrl!) : null,
                      child: e.photoUrl == null ? const Icon(Icons.person, size: 16) : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(e.displayName ?? 'Anonymous',
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
                trailing: Text(e.points.toStringAsFixed(1),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    )),
              ).animate().fade(duration: 220.ms, delay: (12 * i.clamp(0, 14)).ms);
            },
          ),
        ),
      ),
    );
  }
}
