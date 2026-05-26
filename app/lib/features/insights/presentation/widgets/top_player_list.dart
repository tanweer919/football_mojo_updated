import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/models/top_player_dto.dart';

class TopPlayerList extends ConsumerWidget {
  const TopPlayerList({
    super.key,
    required this.provider,
    required this.unit,
    required this.emptyMessage,
  });

  final FutureProvider<List<TopPlayerDto>> provider;
  final String unit;            // 'goals' | 'assists'
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    final theme = Theme.of(context);
    return async.when(
      loading: () => const SkeletonList(itemHeight: 64),
      error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(provider)),
      data: (rows) {
        if (rows.isEmpty) {
          return EmptyState(
            icon: Icons.emoji_events_outlined,
            title: 'Leaderboard is warming up',
            subtitle: emptyMessage,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final p = rows[i];
            return ListTile(
              leading: SizedBox(
                width: 32,
                child: Text('#${i + 1}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              ),
              title: Text(p.playerName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              subtitle: Text(p.teamName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('${p.statValue} $unit',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
              ),
              leadingAndTrailingTextStyle: theme.textTheme.titleMedium,
              dense: false,
              onTap: p.playerId.isEmpty ? null : () => context.push('/players/${p.playerId}'),
            )
                .animate()
                .fade(duration: 200.ms, delay: (10 * i.clamp(0, 14)).ms);
          },
        );
      },
    );
  }
}
