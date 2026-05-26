import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/player_repository.dart';

class PlayerProfileScreen extends ConsumerWidget {
  const PlayerProfileScreen({super.key, required this.playerId});
  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(playerProfileProvider(playerId));
    return Scaffold(
      body: async.when(
        loading: () => const _LoadingScaffold(),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(message: '$e', onRetry: () => ref.invalidate(playerProfileProvider(playerId))),
        ),
        data: (p) => _Body(player: p),
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: const Padding(padding: EdgeInsets.all(16), child: SkeletonList(itemHeight: 80)),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.player});
  final PlayerProfileBundle player;
  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (_, __) => [
        SliverAppBar.large(
          expandedHeight: 260,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(background: _Hero(player: player)),
        ),
      ],
      body: CenteredContent(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _SeasonCard(player: player),
            const SizedBox(height: 16),
            if (player.transfers.isNotEmpty) _Section(title: 'Transfers', child: _Transfers(transfers: player.transfers)),
            if (player.trophies.isNotEmpty)  _Section(title: 'Trophies',  child: _Trophies(trophies: player.trophies)),
            if (player.sidelined.isNotEmpty) _Section(title: 'Sidelined history', child: _Sidelined(sidelined: player.sidelined)),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.player});
  final PlayerProfileBundle player;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primaryContainer, theme.colorScheme.surface],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 96, 20, 16),
      child: Row(
        children: [
          Hero(
            tag: 'player-${player.id}',
            child: Container(
              width: 88, height: 88,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.primary, width: 2),
              ),
              child: player.photo != null
                  ? CachedNetworkImage(imageUrl: player.photo!, fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.person, size: 40))
                  : const Icon(Icons.person, size: 40),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                if (player.teamName != null)
                  Row(children: [
                    if (player.teamLogo != null) CachedNetworkImage(imageUrl: player.teamLogo!, width: 18, height: 18),
                    if (player.teamLogo != null) const SizedBox(width: 6),
                    Flexible(child: Text(player.teamName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall)),
                  ]),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (player.position   != null) _Chip(player.position!),
                    if (player.nationality != null) _Chip(player.nationality!),
                    if (player.height    != null)  _Chip(player.height!),
                    if (player.weight    != null)  _Chip(player.weight!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade(duration: 320.ms);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _SeasonCard extends StatelessWidget {
  const _SeasonCard({required this.player});
  final PlayerProfileBundle player;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = player.seasonStats;
    final cells = [
      _Cell(label: 'Apps',       value: '${s.appearances}'),
      _Cell(label: 'Minutes',    value: '${s.minutes}'),
      _Cell(label: 'Goals',      value: '${s.goals}',   highlight: true),
      _Cell(label: 'Assists',    value: '${s.assists}', highlight: true),
      _Cell(label: 'SoT',        value: '${s.shotsOnTarget}'),
      _Cell(label: 'Yellow',     value: '${s.yellow}'),
      _Cell(label: 'Red',        value: '${s.red}'),
      _Cell(label: 'Pass acc.',  value: s.passAccuracy == 0 ? '—' : '${(s.passAccuracy * 100).toStringAsFixed(0)}%'),
      _Cell(label: 'Rating',     value: s.rating == 0 ? '—' : s.rating.toStringAsFixed(2)),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Season at a glance',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(spacing: 16, runSpacing: 14, children: cells),
          ],
        ),
      ),
    ).animate().fade(duration: 320.ms, delay: 80.ms).slideY(begin: 0.04, end: 0);
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value, this.highlight = false});
  final String label; final String value; final bool highlight;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 78,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: highlight ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Transfers extends StatelessWidget {
  const _Transfers({required this.transfers});
  final List<PlayerTransfer> transfers;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: transfers.take(8).map((t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(t.date.split('-').first,
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${t.from} → ${t.to}',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            if (t.type.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(t.type,
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      )).toList(),
    );
  }
}

class _Trophies extends StatelessWidget {
  const _Trophies({required this.trophies});
  final List<PlayerTrophy> trophies;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wins = trophies.where((t) => t.place.toLowerCase().contains('winner')).toList();
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.emoji_events, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text('${wins.length} titles', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: trophies.take(20).map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: t.place.toLowerCase().contains('winner')
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('${t.competition} · ${t.season}',
                style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          )).toList(),
        ),
      ],
    );
  }
}

class _Sidelined extends StatelessWidget {
  const _Sidelined({required this.sidelined});
  final List<PlayerSidelined> sidelined;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: sidelined.take(6).map((s) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.medical_services_outlined, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(s.type, maxLines: 1, overflow: TextOverflow.ellipsis)),
            Text('${s.start} — ${s.end}', style: theme.textTheme.labelSmall),
          ],
        ),
      )).toList(),
    );
  }
}
