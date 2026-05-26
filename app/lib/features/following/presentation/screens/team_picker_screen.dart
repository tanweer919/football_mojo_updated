import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/sign_in_sheet.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../profile/data/profile_models.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/team_picker_repository.dart';

/// Picker for clubs and national teams. Tapping a row toggles follow/
/// unfollow with optimistic UI; backend is idempotent so a double-tap is
/// safe. The picker is reachable from:
///   - the home "Pick your teams" empty prompt (first-run)
///   - the "Following" section in the profile (always)
class TeamPickerScreen extends ConsumerStatefulWidget {
  const TeamPickerScreen({super.key});
  @override
  ConsumerState<TeamPickerScreen> createState() => _TeamPickerScreenState();
}

class _TeamPickerScreenState extends ConsumerState<TeamPickerScreen> {
  String _query = '';
  String? _competitionFilter;
  Timer? _debounce;
  // Local optimistic snapshot — flips immediately on tap, reconciled when
  // the /me invalidation roundtrips a fresh profile.
  final Set<String> _localFollows = <String>{};
  bool _localHydrated = false;

  static const _competitions = [
    (id: '', label: 'All'),
    (id: 'WC2026', label: 'World Cup'),
    (id: 'PL_2025', label: 'Premier League'),
    (id: 'LALIGA_2025', label: 'La Liga'),
    (id: 'BUNDESLIGA_2025', label: 'Bundesliga'),
    (id: 'SERIEA_2025', label: 'Serie A'),
    (id: 'LIGUE1_2025', label: 'Ligue 1'),
    (id: 'UCL_2025', label: 'Champions League'),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      setState(() => _query = v);
    });
  }

  /// Hydrate the local follow-set from the profile once. After that we own
  /// optimistic state so the toggle feels instant.
  // Profile? because the provider yields `Profile?` (null when signed out).
  // We just no-op until we have a real row to hydrate from.
  void _hydrate(Profile? p) {
    if (_localHydrated || p == null) return;
    _localFollows.addAll(p.followedTeams.map((t) => t.id));
    _localHydrated = true;
  }

  Future<void> _toggle(String teamId, bool currentlyFollowed) async {
    setState(() {
      if (currentlyFollowed) {
        _localFollows.remove(teamId);
      } else {
        _localFollows.add(teamId);
      }
    });
    // Need to be signed in to follow. Trigger Google chooser if not.
    final ensured = await ensureSignedIn(context, ref);
    if (ensured == null) {
      // Sign-in cancelled — roll back the optimistic flip.
      setState(() {
        if (currentlyFollowed) {
          _localFollows.add(teamId);
        } else {
          _localFollows.remove(teamId);
        }
      });
      return;
    }
    try {
      final repo = ref.read(teamPickerRepositoryProvider);
      if (currentlyFollowed) {
        await repo.unfollow(teamId);
      } else {
        await repo.follow(teamId);
      }
    } catch (e) {
      // Rollback + surface the error.
      setState(() {
        if (currentlyFollowed) {
          _localFollows.add(teamId);
        } else {
          _localFollows.remove(teamId);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    profileAsync.whenData(_hydrate);

    final searchArgs = (q: _query, competitionId: _competitionFilter);
    final hitsAsync = ref.watch(teamSearchProvider(searchArgs));

    return PitchScreen(
      title: 'Follow teams',
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      // The screen has its own internal Expanded(list) — passing
      // scrollable:false stops PitchScreen from wrapping the body in a
      // SingleChildScrollView, which would collapse the Expanded to zero
      // height and render a blank picker.
      scrollable: false,
      // Picker manages its own bottom inset (the list pads its own
      // bottom) — disable the tabbar reserve to avoid a visible gap.
      withinTabShell: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Help copy at the top so users understand *why* this matters.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Text(
              _localFollows.isEmpty
                  ? 'Pick the clubs and national teams whose fixtures, results and lineups should sit at the top of your home screen.'
                  : '${_localFollows.length} followed. Tap to add or drop a team — your home will update instantly.',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                color: AppColors.muted,
                height: 1.45,
              ),
            ),
          ),
          // Search bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadii.r3),
                border: Border.all(color: AppColors.borderSoft),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: AppColors.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: AppColors.fg,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Search clubs or national teams…',
                        hintStyle: TextStyle(color: AppColors.muted, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Competition filter chips.
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _competitions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final c = _competitions[i];
                final active = (_competitionFilter ?? '') == c.id;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _competitionFilter = c.id.isEmpty ? null : c.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? AppColors.gold.withValues(alpha: 0.16) : AppColors.surface,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: active ? AppColors.goldHairline : AppColors.borderSoft,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      c.label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: active ? AppColors.gold : AppColors.fgSoft,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: hitsAsync.when(
              loading: () => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: 8,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Skeleton(height: 56, radius: 12),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '$e',
                    style: const TextStyle(color: AppColors.live),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (hits) {
                if (hits.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No teams match. Try a different search or competition.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: hits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final t = hits[i];
                    final followed = _localFollows.contains(t.id);
                    return _TeamRow(
                      team: t,
                      followed: followed,
                      onTap: () => _toggle(t.id, followed),
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

class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.team, required this.followed, required this.onTap});
  final TeamHit team;
  final bool followed;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r3),
          border: Border.all(color: followed ? AppColors.goldHairline : AppColors.borderSoft),
          color: followed ? AppColors.gold.withValues(alpha: 0.10) : AppColors.surface2,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 32, height: 32,
              child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.fg,
                      letterSpacing: -0.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Eyebrow(
                    team.competitionName ?? team.countryCode ?? '—',
                    size: 9,
                    color: followed ? AppColors.goldDeep : AppColors.muted,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: followed
                  ? Container(
                      key: const ValueKey('on'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check, size: 12, color: Color(0xFF1E1810)),
                          SizedBox(width: 4),
                          Text(
                            'FOLLOWING',
                            style: TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E1810),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GhostButton(
                      key: const ValueKey('off'),
                      label: 'Follow',
                      onPressed: onTap,
                      small: true,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
