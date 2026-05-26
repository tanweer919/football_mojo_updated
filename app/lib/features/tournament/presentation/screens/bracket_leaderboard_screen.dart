import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/share/share_service.dart';
import '../../../predictions/data/predictions_repository.dart';
import '../widgets/bracket_leaderboard_share_card.dart';

class BracketLeaderboardScreen extends ConsumerWidget {
  const BracketLeaderboardScreen({super.key, this.competitionId = 'WC2026'});
  final String competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = ref.watch(bracketLeaderboardProvider(competitionId));
    final myUid = ref.watch(authStateProvider).maybeWhen(
          data: (u) => u?.uid,
          orElse: () => null,
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bracket leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () {
              final list = rows.valueOrNull;
              if (list == null || list.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No standings yet — they appear once the group stage starts scoring.',
                    ),
                  ),
                );
                return;
              }
              ShareService.instance.shareArtifact(
                context: context,
                logicalSize: const Size(1080, 1350),
                text: 'Live bracket standings on PITCH',
                filename: 'pitch_bracket_leaderboard.png',
                builder: (_) => BracketLeaderboardShareCard(
                  rows: list,
                  myUserId: myUid,
                ),
              );
            },
          ),
        ],
      ),
      body: rows.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No brackets scored yet. Once the group stage ends, '
                  'standings will appear here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(bracketLeaderboardProvider(competitionId)),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final row = list[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage:
                        row.photoUrl != null ? NetworkImage(row.photoUrl!) : null,
                    child: row.photoUrl == null
                        ? Text(
                            (row.displayName?.isNotEmpty ?? false)
                                ? row.displayName![0].toUpperCase()
                                : '?',
                          )
                        : null,
                  ),
                  title: Text(
                    row.displayName ?? 'Manager',
                    style:
                        const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle:
                      row.countryCode != null ? Text(row.countryCode!) : null,
                  leadingAndTrailingTextStyle:
                      theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                  trailing: Text(
                    '${row.total} pts',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ).animate().fade(duration: 180.ms, delay: (15 * i).ms);
              },
            ),
          );
        },
      ),
    );
  }
}
