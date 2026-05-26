import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/router/route_paths.dart';
import '../../data/h2h_repository.dart';

/// Deep-link target for /h2h/i/:token. Resolvable without sign-in so the
/// preview renders before redemption; redemption itself requires auth.
class H2HInviteScreen extends ConsumerWidget {
  const H2HInviteScreen({super.key, required this.token});
  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = ref.watch(h2hInvitePreviewProvider(token));
    final signedIn =
        ref.watch(authStateProvider).maybeWhen(data: (u) => u != null, orElse: () => false);

    return Scaffold(
      appBar: AppBar(title: const Text('1v1 invite')),
      body: preview.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (p) {
          final theme = Theme.of(context);
          return SafeArea(
            // AppBar handles the top inset; we only need bottom protection
            // so the Accept-challenge button clears the iOS home indicator.
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: p.challenger.photoUrl != null
                          ? CachedNetworkImageProvider(p.challenger.photoUrl!)
                          : null,
                      child: p.challenger.photoUrl == null
                          ? const Icon(Icons.person, size: 28)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.challenger.displayName ?? 'A player',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'wants to face you on PITCH',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _InfoTile(label: 'Tournament', value: p.tournamentName),
                _InfoTile(label: 'Gameweek', value: p.gameweekName),
                _InfoTile(
                  label: 'Deadline',
                  value: _formatDate(p.lockAt),
                ),
                if (p.message != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('"${p.message!}"',
                        style: const TextStyle(fontStyle: FontStyle.italic)),
                  ),
                ],
                const Spacer(),
                if (p.claimed)
                  _Notice(text: 'This invite has already been accepted.', error: true)
                else if (p.expired)
                  _Notice(text: 'This invite has expired — the deadline passed.', error: true)
                else if (!signedIn)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Notice(
                          text: 'Sign in to accept this challenge.',
                          error: false),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Sign in to accept'),
                        onPressed: () => context.push(RoutePaths.signIn),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    icon: const Icon(Icons.sports_kabaddi_rounded),
                    label: const Text('Accept challenge'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () async {
                      try {
                        await ref.read(h2hRepositoryProvider).acceptInvite(token);
                        ref.invalidate(h2hListProvider);
                        if (!context.mounted) return;
                        context.go(RoutePaths.h2h);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$e')),
                        );
                      }
                    },
                  ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$m-$d at $hh:$mm';
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(
            child: Text(value,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.error});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = error ? theme.colorScheme.error : theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(text, style: theme.textTheme.bodyMedium),
    );
  }
}
