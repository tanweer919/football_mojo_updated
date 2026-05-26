import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/fcm_service.dart';
import '../../data/profile_repository.dart';

/// Toggle UI for what the user gets pushed about. All categories default
/// to on server-side; this screen surfaces every category so users can
/// opt out granularly.
class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  /// Local pending state — applied on toggle, debounced server write.
  /// Initialised from the server response so missing keys don't reset.
  Map<String, bool>? _local;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPrefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: prefs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (p) {
          // Hydrate the local map on first build so toggles feel instant.
          _local ??= {
            'matchGoals': p.matchGoals,
            'matchKickoff': p.matchKickoff,
            'matchFulltime': p.matchFulltime,
            'matchLineup': p.matchLineup,
            'breakingNews': p.breakingNews,
            'wcDailyRecap': p.wcDailyRecap,
            'fantasyResults': p.fantasyResults,
            'h2hInvites': p.h2hInvites,
            'h2hResults': p.h2hResults,
            'cardDrops': p.cardDrops,
          };
          return ListView(
            children: [
              _Group(title: 'World Cup', children: [
                _Toggle(
                  label: 'Daily recap',
                  desc: 'A one-minute summary every morning.',
                  value: _local!['wcDailyRecap']!,
                  onChanged: (v) => _toggle('wcDailyRecap', v, syncWcDigest: true),
                ),
                _Toggle(
                  label: 'Breaking news',
                  desc: 'Big stories the moment they break.',
                  value: _local!['breakingNews']!,
                  onChanged: (v) => _toggle('breakingNews', v, syncBreakingNews: true),
                ),
              ]),
              _Group(title: 'Live matches', children: [
                _Toggle(
                  label: 'Goals',
                  desc: 'When your followed teams score or concede.',
                  value: _local!['matchGoals']!,
                  onChanged: (v) => _toggle('matchGoals', v),
                ),
                _Toggle(
                  label: 'Kick-off',
                  desc: 'When followed teams take the pitch.',
                  value: _local!['matchKickoff']!,
                  onChanged: (v) => _toggle('matchKickoff', v),
                ),
                _Toggle(
                  label: 'Full-time',
                  desc: 'Final score the second it lands.',
                  value: _local!['matchFulltime']!,
                  onChanged: (v) => _toggle('matchFulltime', v),
                ),
                _Toggle(
                  label: 'Confirmed XI',
                  desc: 'Starting lineups about an hour before kickoff.',
                  value: _local!['matchLineup']!,
                  onChanged: (v) => _toggle('matchLineup', v),
                ),
              ]),
              _Group(title: 'Fantasy & 1v1', children: [
                _Toggle(
                  label: 'Gameweek results',
                  desc: 'Your rank + points when scoring closes.',
                  value: _local!['fantasyResults']!,
                  onChanged: (v) => _toggle('fantasyResults', v),
                ),
                _Toggle(
                  label: '1v1 invites',
                  desc: 'When someone accepts your challenge link.',
                  value: _local!['h2hInvites']!,
                  onChanged: (v) => _toggle('h2hInvites', v),
                ),
                _Toggle(
                  label: '1v1 results',
                  desc: 'Who won the head-to-head.',
                  value: _local!['h2hResults']!,
                  onChanged: (v) => _toggle('h2hResults', v),
                ),
              ]),
              _Group(title: 'Cards', children: [
                _Toggle(
                  label: 'New card drops',
                  desc: 'Stage-locked editions opening in the store.',
                  value: _local!['cardDrops']!,
                  onChanged: (v) => _toggle('cardDrops', v),
                ),
              ]),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(
                    child: SizedBox(
                      height: 14, width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggle(
    String key,
    bool value, {
    bool syncWcDigest = false,
    bool syncBreakingNews = false,
  }) async {
    setState(() {
      _local![key] = value;
      _busy = true;
    });
    try {
      await ref.read(profileRepositoryProvider)
          .setNotificationPreferences({key: value});
      // Side-effects: device-level topic subscriptions for the two
      // broadcast streams. Backend's PushService gates push on the
      // server-side preference; topic subscription gates *delivery* at
      // the FCM level so opt-out is enforced both ways.
      if (syncWcDigest) {
        await FcmBootstrap.setWcDigestSubscription(value);
      }
      if (syncBreakingNews) {
        await FcmBootstrap.setBreakingNewsSubscription(value);
      }
      ref.invalidate(notificationPrefsProvider);
    } catch (e) {
      if (!mounted) return;
      // Roll back on failure.
      setState(() => _local![key] = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't save — try again")),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              title.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.desc,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(desc),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    );
  }
}
