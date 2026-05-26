import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/awards_repository.dart';

/// Three-pick "who wins what" screen. One pick per award type.
class AwardPicksScreen extends ConsumerWidget {
  const AwardPicksScreen({super.key, this.competitionId = 'WC2026'});
  final String competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myAwardPicksProvider(competitionId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Tournament awards')),
      body: mine.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (picks) {
          final byType = {for (final p in picks) p.awardType: p};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Pick before the first whistle. 150 gems + 100 points per correct call. Locks once the WC starts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final type in AwardType.values)
                _AwardSection(
                  competitionId: competitionId,
                  awardType: type,
                  currentPick: byType[type],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AwardSection extends ConsumerWidget {
  const _AwardSection({
    required this.competitionId,
    required this.awardType,
    required this.currentPick,
  });
  final String competitionId;
  final AwardType awardType;
  final AwardPick? currentPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.emoji_events_rounded,
                    color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  awardType.label.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              awardType.tagline,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            if (currentPick?.player != null)
              _PickedPlayer(pick: currentPick!)
            else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text('No pick yet.'),
              ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.person_search_rounded, size: 18),
                label: Text(currentPick == null ? 'Pick a player' : 'Change pick'),
                onPressed: () => _openPicker(context, ref),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<AwardPlayer>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CandidatePicker(
        competitionId: competitionId,
        awardType: awardType,
      ),
    );
    if (picked == null) return;
    try {
      await ref.read(awardsRepositoryProvider).submitPick(
            competitionId: competitionId,
            awardType: awardType,
            playerId: picked.id,
          );
      ref.invalidate(myAwardPicksProvider(competitionId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendly('$e'))),
      );
    }
  }

  String _friendly(String raw) {
    if (raw.contains('awards_locked')) return 'Picks are locked — the tournament has started.';
    if (raw.contains('player_not_in_competition')) return 'That player isn\'t in this tournament.';
    return 'Couldn\'t save your pick. Try again.';
  }
}

class _PickedPlayer extends StatelessWidget {
  const _PickedPlayer({required this.pick});
  final AwardPick pick;

  @override
  Widget build(BuildContext context) {
    final p = pick.player!;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.18),
            theme.colorScheme.primary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage:
                p.photoUrl != null ? CachedNetworkImageProvider(p.photoUrl!) : null,
            child: p.photoUrl == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (p.teamName != null)
                  Text(
                    p.teamName!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (pick.scoredAt != null && pick.pointsAwarded > 0)
            Text(
              '+${pick.pointsAwarded}',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
        ],
      ),
    );
  }
}

class _CandidatePicker extends ConsumerWidget {
  const _CandidatePicker({
    required this.competitionId,
    required this.awardType,
  });
  final String competitionId;
  final AwardType awardType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(awardCandidatesProvider(
      (competitionId: competitionId, awardType: awardType),
    ));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Text('Pick a ${awardType.label}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: candidates.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No candidates yet.'));
                }
                return ListView.separated(
                  controller: scrollCtrl,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = list[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: p.photoUrl != null
                            ? CachedNetworkImageProvider(p.photoUrl!)
                            : null,
                        child: p.photoUrl == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: p.teamName != null ? Text(p.teamName!) : null,
                      onTap: () => Navigator.of(context).pop(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
