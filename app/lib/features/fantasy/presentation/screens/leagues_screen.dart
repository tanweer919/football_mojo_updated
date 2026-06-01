import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/deeplink/chottu_link_service.dart';
import '../../../../core/router/route_paths.dart';
import '../../data/models/league_models.dart';
import '../../data/repositories/fantasy_repository.dart';
import '../providers/fantasy_providers.dart';

/// Lists the signed-in user's private leagues for a tournament, and lets
/// them create a new one or join via a 6-character code.
class LeaguesScreen extends ConsumerWidget {
  const LeaguesScreen({
    super.key,
    this.slug = kGlobalCupSlug,
  });
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournament = ref.watch(tournamentProvider(slug));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Private leagues')),
      body: tournament.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (t) {
          final leagues = ref.watch(myLeaguesProvider(t.id));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Beat your friends — leagues filter the global leaderboard '
                  'down to people you actually know.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Create league'),
                        onPressed: () => _openCreate(context, ref, t.id),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.vpn_key_rounded),
                        label: const Text('Join by code'),
                        onPressed: () => _openJoin(context, ref),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: leagues.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('$e')),
                  data: (list) {
                    if (list.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No leagues yet. Create one and share the code in '
                            'your group chat.',
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
                          ref.invalidate(myLeaguesProvider(t.id)),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _LeagueCard(
                          league: list[i],
                          slug: slug,
                          onLeft: () =>
                              ref.invalidate(myLeaguesProvider(t.id)),
                        ).animate().fade(duration: 220.ms, delay: (40 * i).ms),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref, String tournamentId) async {
    final controller = TextEditingController();
    final created = await showModalBottomSheet<FantasyLeagueSummary>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create a private league',
                style: Theme.of(ctx).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLength: 40,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'League name',
                hintText: 'e.g. "Office World Cup"',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.length < 3) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Name must be 3+ characters.')),
                  );
                  return;
                }
                try {
                  final league = await ref
                      .read(fantasyRepositoryProvider)
                      .createLeague(tournamentId: tournamentId, name: name);
                  if (ctx.mounted) Navigator.of(ctx).pop(league);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (created != null) {
      ref.invalidate(myLeaguesProvider(tournamentId));
      if (context.mounted) _showJoinCode(context, created);
    }
  }

  Future<void> _openJoin(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final joined = await showModalBottomSheet<FantasyLeagueSummary>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Join with a code',
                style: Theme.of(ctx).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 6,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                _UpperCaseFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Join code',
                hintText: 'e.g. K7H2X9',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                final code = controller.text.trim();
                if (code.length != 6) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Codes are 6 characters.')),
                  );
                  return;
                }
                try {
                  final league = await ref
                      .read(fantasyRepositoryProvider)
                      .joinLeague(code);
                  if (ctx.mounted) Navigator.of(ctx).pop(league);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Join'),
            ),
          ],
        ),
      ),
    );
    if (joined != null) {
      ref.invalidate(myLeaguesProvider(null));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined "${joined.name}".')),
        );
      }
    }
  }

  void _showJoinCode(BuildContext context, FantasyLeagueSummary league) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('League created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(league.name,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            const Text('Share this code with friends:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                league.joinCode,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: league.joinCode));
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Code copied')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () {
              ChottuLinkService.instance.shareLeague(
                leagueId: league.id,
                leagueName: league.name,
                slug: slug,
              );
            },
            child: const Text('Invite friends'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _LeagueCard extends ConsumerWidget {
  const _LeagueCard({
    required this.league,
    required this.slug,
    required this.onLeft,
  });
  final FantasyLeagueSummary league;
  final String slug;
  final VoidCallback onLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gw = ref.watch(currentGameweekProvider(slug));
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final gwId = gw.maybeWhen(data: (g) => g?.id, orElse: () => null);
          if (gwId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No active gameweek yet.')),
            );
            return;
          }
          final path = RoutePaths.fantasyLeaderboard
              .replaceAll(':slug', slug)
              .replaceAll(':gwId', gwId);
          context.push('$path?league=${league.id}');
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      league.name,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${league.memberCount} / ${league.memberLimit} members  ·  Code ${league.joinCode}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy code',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: league.joinCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Code "${league.joinCode}" copied')),
                  );
                },
              ),
              IconButton(
                tooltip: 'Invite',
                icon: const Icon(Icons.share_rounded),
                onPressed: () {
                  ChottuLinkService.instance.shareLeague(
                    leagueId: league.id,
                    leagueName: league.name,
                    slug: slug,
                  );
                },
              ),
              if (!league.isOwner)
                IconButton(
                  tooltip: 'Leave',
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Leave league?'),
                        content: Text('Leave "${league.name}"?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel')),
                          FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Leave')),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    try {
                      await ref
                          .read(fantasyRepositoryProvider)
                          .leaveLeague(league.id);
                      onLeft();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
