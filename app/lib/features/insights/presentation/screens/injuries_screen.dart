import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/insights_repository.dart';
import '../../data/models/injury_dto.dart';

class InjuriesScreen extends ConsumerWidget {
  const InjuriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(injuriesProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Injuries')),
      body: CenteredContent(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(injuriesProvider),
          child: async.when(
            loading: () => const SkeletonList(itemHeight: 80),
            error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(injuriesProvider)),
            data: (rows) {
              if (rows.isEmpty) {
                return const EmptyState(
                  icon: Icons.medical_services_outlined,
                  title: 'No reported injuries',
                  subtitle: 'Updates flow in from official team announcements.',
                );
              }
              // Group by team.
              final byTeam = <String, List<InjuryDto>>{};
              for (final i in rows) byTeam.putIfAbsent(i.teamName, () => []).add(i);
              final entries = byTeam.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final teamEntries = entries[i].value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (teamEntries.first.teamLogo != null)
                                  CachedNetworkImage(
                                    imageUrl: teamEntries.first.teamLogo!,
                                    width: 24, height: 24,
                                    errorWidget: (_, __, ___) => const Icon(Icons.shield_outlined, size: 20),
                                  ),
                                const SizedBox(width: 8),
                                Text(entries[i].key,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                              ],
                            ),
                            const Divider(height: 18),
                            for (final inj in teamEntries) _Row(injury: inj),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fade(duration: 240.ms, delay: (60 * i.clamp(0, 12)).ms).slideY(begin: 0.04, end: 0);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.injury});
  final InjuryDto injury;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOut = injury.type.toLowerCase().contains('missing');
    final color = isOut ? theme.colorScheme.error : const Color(0xFFE6B800);
    return Builder(builder: (ctx) {
      return InkWell(
        onTap: injury.playerId.isEmpty ? null : () => ctx.push('/players/${injury.playerId}'),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: injury.playerPhoto != null ? CachedNetworkImageProvider(injury.playerPhoto!) : null,
                child: injury.playerPhoto == null ? const Icon(Icons.person, size: 18) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(injury.playerName, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(injury.reason,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
                child: Text(isOut ? 'OUT' : 'DOUBT',
                    style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
              ),
            ],
          ),
        ),
      );
    });
  }
}
