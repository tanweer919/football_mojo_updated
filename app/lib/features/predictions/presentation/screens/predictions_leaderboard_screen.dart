import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/predictions_repository.dart';

class PredictionsLeaderboardScreen extends ConsumerWidget {
  const PredictionsLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(predictionsLeaderboardProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Predictions leaderboard')),
      body: CenteredContent(
        child: list.when(
          loading: () => const SkeletonList(itemHeight: 56),
          error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(predictionsLeaderboardProvider)),
          data: (rows) => ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => ListTile(
              leading: SizedBox(width: 36, child: Text('#${i + 1}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
              title: Text(rows[i].displayName ?? 'Anonymous'),
              trailing: Text('${rows[i].total} pts',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
            ).animate().fade(duration: 200.ms, delay: (10 * i.clamp(0, 14)).ms),
          ),
        ),
      ),
    );
  }
}
