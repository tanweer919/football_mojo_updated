import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/h2h_repository.dart';

class H2HLadderScreen extends ConsumerWidget {
  const H2HLadderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ladder = ref.watch(h2hLadderProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('1v1 Ladder')),
      body: ladder.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (rows) {
          if (rows.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'No resolved challenges yet. Accept a friend\'s invite and '
                  'finish a gameweek to climb the ladder.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(h2hLadderProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = rows[i];
                final winRate =
                    r.played == 0 ? 0.0 : (r.wins / r.played * 100);
                return ListTile(
                  leading: SizedBox(
                    width: 36,
                    child: Text('#${r.rank}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w800)),
                  ),
                  title: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundImage: r.photoUrl != null
                            ? CachedNetworkImageProvider(r.photoUrl!)
                            : null,
                        child: r.photoUrl == null
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.displayName ??
                              (r.userTag != null ? '@${r.userTag}' : 'Player'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${r.wins}W / ${r.played}G  ·  ${winRate.toStringAsFixed(0)}% win rate',
                  ),
                  trailing: Text(
                    '${r.wins}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ).animate().fade(duration: 220.ms, delay: (12 * i.clamp(0, 14)).ms);
              },
            ),
          );
        },
      ),
    );
  }
}
