import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/models/fantasy_models.dart';
import '../providers/fantasy_providers.dart';
import '../providers/live_scoring_provider.dart';
import '../widgets/live_badge.dart';

class FantasyLeaderboardScreen extends ConsumerWidget {
  const FantasyLeaderboardScreen({
    super.key,
    required this.slug,
    required this.gameweekId,
    this.leagueId,
  });
  final String slug;
  final String gameweekId;

  /// When non-null, scopes the leaderboard to a single private league.
  /// When null, shows the global leaderboard with a button to switch into
  /// a friends-only view.
  final String? leagueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLeague = leagueId != null;
    final AsyncValue<List<LeaderboardEntry>> rows = isLeague
        ? ref.watch(leagueLeaderboardProvider((leagueId: leagueId!, gameweekId: gameweekId)))
        : ref.watch(leaderboardProvider((slug: slug, gameweekId: gameweekId)));

    final liveAsync = ref.watch(fantasyLivePollingProvider(
      (slug: slug, gameweekId: gameweekId),
    ));
    final isLive = liveAsync.maybeWhen(data: (v) => v, orElse: () => false);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isLeague ? 'League standings' : 'Leaderboard'),
            if (isLive) ...const [SizedBox(width: 10), LiveBadge()],
          ],
        ),
        actions: [
          IconButton(
            tooltip: isLeague ? 'Global leaderboard' : 'My leagues',
            icon: Icon(isLeague ? Icons.public_rounded : Icons.groups_rounded),
            onPressed: () {
              if (isLeague) {
                final path = RoutePaths.fantasyLeaderboard
                    .replaceAll(':slug', slug)
                    .replaceAll(':gwId', gameweekId);
                context.go(path);
              } else {
                context.push(
                  RoutePaths.fantasyLeagues.replaceAll(':slug', slug),
                );
              }
            },
          ),
        ],
      ),
      body: CenteredContent(
        child: Column(
          children: [
            _ScopeChip(isLeague: isLeague, slug: slug, gameweekId: gameweekId),
            Expanded(
              child: rows.when(
                loading: () => const SkeletonList(itemHeight: 64),
                error: (e, _) => ErrorView(
                  message: '$e',
                  onRetry: () => isLeague
                      ? ref.invalidate(leagueLeaderboardProvider(
                          (leagueId: leagueId!, gameweekId: gameweekId)))
                      : ref.invalidate(leaderboardProvider(
                          (slug: slug, gameweekId: gameweekId))),
                ),
                data: (entries) {
                  if (entries.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          isLeague
                              ? 'No standings yet — wait for league members to '
                                'submit lineups for this gameweek.'
                              : 'No standings yet for this gameweek.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
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
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ),
                        title: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundImage: e.photoUrl != null
                                  ? CachedNetworkImageProvider(e.photoUrl!)
                                  : null,
                              child: e.photoUrl == null
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(e.displayName ?? 'Anonymous',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        trailing: Text(
                          e.points.toStringAsFixed(1),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ).animate().fade(
                            duration: 220.ms,
                            delay: (12 * i.clamp(0, 14)).ms,
                          );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.isLeague,
    required this.slug,
    required this.gameweekId,
  });
  final bool isLeague;
  final String slug;
  final String gameweekId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _SegButton(
                label: 'Global',
                selected: !isLeague,
                onTap: () {
                  if (!isLeague) return;
                  final path = RoutePaths.fantasyLeaderboard
                      .replaceAll(':slug', slug)
                      .replaceAll(':gwId', gameweekId);
                  GoRouter.of(context).go(path);
                },
              ),
            ),
            Expanded(
              child: _SegButton(
                label: 'My leagues',
                selected: isLeague,
                onTap: () {
                  if (isLeague) return;
                  GoRouter.of(context).push(
                    RoutePaths.fantasyLeagues.replaceAll(':slug', slug),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegButton extends StatelessWidget {
  const _SegButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? theme.colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
