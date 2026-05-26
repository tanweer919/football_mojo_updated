import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/notifications/fcm_service.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/share/share_service.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/h2h_repository.dart';
import '../widgets/challenge_composer.dart';
import '../widgets/h2h_share_card.dart';

class H2HScreen extends ConsumerStatefulWidget {
  const H2HScreen({super.key});
  @override
  ConsumerState<H2HScreen> createState() => _H2HScreenState();
}

class _H2HScreenState extends ConsumerState<H2HScreen> {
  @override
  void initState() {
    super.initState();
    // Best-effort: prompt for notification permission + register the
    // current FCM token so H2H invite-accept / result pushes can land.
    // Fires on screen mount — no-op if already registered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = ref.read(authStateProvider).maybeWhen(
            data: (u) => u?.uid,
            orElse: () => null,
          );
      if (uid == null) return;
      FcmBootstrap.ensureRegistered(ref.read(dioProvider));
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(h2hListProvider);
    final myUid = ref.watch(authStateProvider).maybeWhen(data: (u) => u?.uid, orElse: () => null);
    return Scaffold(
      appBar: AppBar(
        title: const Text('1v1 Challenges'),
        actions: [
          IconButton(
            tooltip: 'Ladder',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => context.push(RoutePaths.h2hLadder),
          ),
        ],
      ),
      body: CenteredContent(
        child: list.when(
          loading: () => const SkeletonList(itemHeight: 96),
          error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(h2hListProvider)),
          data: (challenges) {
            if (challenges.isEmpty) {
              return const EmptyState(
                icon: Icons.sports_kabaddi,
                title: 'No challenges yet',
                subtitle: 'Tap the plus button to challenge a friend.',
              );
            }
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(h2hListProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: challenges.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ChallengeCard(challenge: challenges[i], myUid: myUid, indexInList: i),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Challenge'),
        onPressed: () => showH2HChallengeComposer(context),
      ),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({required this.challenge, required this.myUid, required this.indexInList});
  final H2HChallenge challenge;
  final String? myUid;
  final int indexInList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final amChallenger = myUid != null && myUid == challenge.challenger.id;
    final amOpponent   = myUid != null && challenge.opponent != null && myUid == challenge.opponent!.id;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                _Side(user: challenge.challenger, score: challenge.challengerScore, winner: challenge.winnerId == challenge.challenger.id),
                Expanded(
                  child: Column(
                    children: [
                      Text(challenge.gameweekName,
                          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      _StatusChip(status: challenge.status, winner: challenge.winnerId != null),
                      if (challenge.status == H2HStatus.RESOLVED) ...[
                        const SizedBox(height: 6),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Share result',
                          icon: const Icon(Icons.ios_share_rounded, size: 18),
                          onPressed: () => ShareService.instance.shareArtifact(
                            context: context,
                            logicalSize: const Size(1080, 1080),
                            text: 'My PITCH 1v1 result',
                            filename: 'pitch_h2h.png',
                            builder: (_) => H2HShareCard(challenge: challenge),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                challenge.opponent == null
                    ? const _WaitingSide()
                    : _Side(
                        user: challenge.opponent!,
                        score: challenge.opponentScore,
                        winner: challenge.winnerId == challenge.opponent!.id,
                        alignEnd: true,
                      ),
              ],
            ),
            if (challenge.opponent == null &&
                challenge.inviteToken != null &&
                challenge.status == H2HStatus.PENDING) ...[
              const Divider(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy link'),
                      onPressed: () {
                        final link = _inviteLink(challenge.inviteToken!);
                        Clipboard.setData(ClipboardData(text: link));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite link copied')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share'),
                      onPressed: () {
                        final link = _inviteLink(challenge.inviteToken!);
                        SharePlus.instance.share(
                          ShareParams(
                            text:
                                'Challenge me on PITCH for ${challenge.gameweekName}: $link',
                            subject: 'PITCH 1v1 invite',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
            if (challenge.status == H2HStatus.PENDING && amOpponent) ...[
              const Divider(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref.read(h2hRepositoryProvider).decline(challenge.id);
                        ref.invalidate(h2hListProvider);
                      },
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        await ref.read(h2hRepositoryProvider).accept(challenge.id);
                        ref.invalidate(h2hListProvider);
                      },
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ] else if (challenge.status == H2HStatus.PENDING && amChallenger) ...[
              const Divider(height: 22),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(h2hRepositoryProvider).cancel(challenge.id);
                    ref.invalidate(h2hListProvider);
                  },
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fade(duration: 260.ms, delay: (40 * indexInList).ms).slideY(begin: 0.04, end: 0);
  }
}

String _inviteLink(String token) => 'https://pitch.app/h2h/i/$token';

class _WaitingSide extends StatelessWidget {
  const _WaitingSide();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            child: Icon(Icons.person_add_outlined,
                size: 22, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Text('Waiting…',
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('—',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({required this.user, required this.score, required this.winner, this.alignEnd = false});
  final H2HUserSummary user;
  final double score;
  final bool winner;
  final bool alignEnd;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final col = Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundImage: user.photoUrl != null ? CachedNetworkImageProvider(user.photoUrl!) : null,
          child: user.photoUrl == null ? const Icon(Icons.person, size: 22) : null,
        ),
        const SizedBox(height: 6),
        Text(user.displayName ?? 'User',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(score.toStringAsFixed(1),
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: winner ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()])),
      ],
    );
    return SizedBox(width: 92, child: col);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.winner});
  final H2HStatus status;
  final bool winner;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = switch (status) {
      H2HStatus.PENDING   => theme.colorScheme.tertiaryContainer,
      H2HStatus.ACCEPTED  => theme.colorScheme.primaryContainer,
      H2HStatus.LOCKED    => theme.colorScheme.secondaryContainer,
      H2HStatus.RESOLVED  => winner ? theme.colorScheme.primary.withValues(alpha: 0.18) : theme.colorScheme.surfaceContainerHighest,
      H2HStatus.DECLINED  => theme.colorScheme.errorContainer,
      H2HStatus.CANCELLED => theme.colorScheme.surfaceContainerHighest,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: palette, borderRadius: BorderRadius.circular(99)),
      child: Text(status.name,
          style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0.6)),
    );
  }
}
