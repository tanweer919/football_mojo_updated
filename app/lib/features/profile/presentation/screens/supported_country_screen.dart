import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/fcm_service.dart';
import '../../../world_cup/data/world_cup_models.dart';
import '../../../world_cup/data/world_cup_repository.dart';
import '../../data/profile_repository.dart';

/// Pick the country to support during the WC. Updates the profile, syncs
/// the FCM topic subscription, and refreshes the profile provider so the
/// rest of the app picks up the change.
class SupportedCountryScreen extends ConsumerWidget {
  const SupportedCountryScreen({
    super.key,
    this.competitionId = 'WC2026',
  });
  final String competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(wcGroupsProvider(competitionId));
    final me = ref.watch(myProfileProvider).valueOrNull;
    final current = me?.supportedCountryCode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick your country'),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => _save(context, ref, null),
              child: const Text('Clear'),
            ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (groups) {
          // Flatten all team entries from every group into one alphabetic list.
          final teams = <WcTeamRef>[
            for (final g in groups) ...g.standings.map((s) => s.team),
          ]..sort((a, b) => a.name.compareTo(b.name));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  'Country-themed home accents, supporter-only leaderboards, and push alerts when your country plays.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: teams.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final t = teams[i];
                    final selected = current == t.countryCode || current == t.id;
                    return ListTile(
                      leading: t.crestUrl != null
                          ? CircleAvatar(
                              backgroundImage: NetworkImage(t.crestUrl!),
                              backgroundColor: Colors.transparent,
                            )
                          : const CircleAvatar(child: Icon(Icons.flag_outlined)),
                      title: Text(t.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: t.countryCode != null ? Text(t.countryCode!) : null,
                      trailing: selected
                          ? const Icon(Icons.check_circle_rounded, color: Colors.amber)
                          : null,
                      onTap: () => _save(context, ref, t.countryCode ?? t.id),
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

  Future<void> _save(BuildContext context, WidgetRef ref, String? code) async {
    try {
      await ref.read(profileRepositoryProvider).setSupportedCountry(code);
      await FcmBootstrap.syncSupportedCountry(code);
      ref.invalidate(myProfileProvider);
      if (!context.mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}
