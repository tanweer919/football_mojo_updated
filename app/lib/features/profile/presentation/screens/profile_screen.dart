import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_paths.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/auth/sign_in_sheet.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_hero_stack.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/profile_models.dart';
import '../../data/profile_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    return PitchScreen(
      title: 'Account',
      // Profile is always reached via push (avatar tap from Home).
      // Always show the back affordance — `context.canPop()` returns false
      // inside the ShellRoute branch even when the Navigator can pop.
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      child: profile.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Skeleton(height: 320, radius: 16),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text('$e', style: const TextStyle(color: AppColors.live)),
        ),
        data: (p) {
          if (p == null) return const _SignedOutAccount();
          return _ProfileBody(profile: p);
        },
      ),
    );
  }
}

/// Signed-out account view — reuses the onboarding visual vocabulary
/// (`PitchGridBackground` + 3D `PitchHeroStack`) so the unauthenticated
/// profile tab still feels premium and brand-consistent, rather than the
/// previous plain-text empty state.
class _SignedOutAccount extends ConsumerWidget {
  const _SignedOutAccount();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenH = MediaQuery.sizeOf(context).height;
    final screenW = MediaQuery.sizeOf(context).width;
    final cardW = (screenW * 0.46).clamp(140.0, 180.0);
    final stackH = (screenH * 0.30).clamp(220.0, 360.0);

    return Column(
      children: [
        const SizedBox(height: 16),
        // 3D card stack.
        PitchHeroStack(height: stackH, cardWidth: cardW),
        const SizedBox(height: 32),
        // Bottom block — copy + CTA.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Eyebrow('Your account', gold: true, size: 11),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.12,
                    color: AppColors.fg,
                    height: 1.05,
                  ),
                  children: [
                    TextSpan(text: 'Sign in to claim\nyour '),
                    TextSpan(
                      text: 'collection',
                      style: TextStyle(
                        fontFamily: 'IowanOldStyle',
                        fontFamilyFallback: ['Charter', 'Georgia', 'serif'],
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gold,
                      ),
                    ),
                    TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Save your XI, mint cards from prize finishes, and sync your collection across devices.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 18),
              GoldButton(
                label: 'Continue with Google',
                icon: Icons.g_mobiledata,
                expand: true,
                onPressed: () async {
                  final user = await quickSignIn(context, ref);
                  if (user != null) ref.invalidate(myProfileProvider);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              _Hero(profile: p),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _StatsRow(stats: p.stats),
              ),
              const SectionHead(title: 'Achievements'),
              if (p.achievements.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'No achievements yet — play a gameweek or complete a card set to unlock your first.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    children: p.achievements.take(8).map(_AchvBadge.new).toList(),
                  ),
                ),
              const SectionHead(title: 'Following'),
              if (p.followedTeams.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Pin teams to follow from any match page.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                )
              else
                SizedBox(
                  height: 86,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: p.followedTeams.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _FollowCard(team: p.followedTeams[i]),
                  ),
                ),
              const SectionHead(title: 'Account'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SettingsGroup(rows: [
                  // Account-info rows are read-only — no chevron, no tap.
                  _SettingRow(icon: Icons.email_outlined, label: 'Email', value: p.email ?? '—'),
                  _SettingRow(
                    icon: Icons.diamond_outlined,
                    label: 'Member since',
                    value: DateFormat.yMMMd().format(p.memberSince.toLocal()),
                  ),
                  // (PITCH Pro row hidden — the tier isn't shipping yet.)
                ]),
              ),
              const SectionHead(title: 'Wallet'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SettingsGroup(rows: [
                  // Coins removed — current build only spends/earns gems.
                  _SettingRow(
                    icon: Icons.diamond,
                    label: 'Gems',
                    value: '${p.gems}',
                    gold: true,
                    onTap: () => context.push(RoutePaths.wallet),
                  ),
                ]),
              ),
              const SectionHead(title: 'World Cup'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SettingsGroup(rows: [
                  _SettingRow(
                    icon: Icons.flag_rounded,
                    label: 'Country I support',
                    value: p.supportedCountryCode ?? 'Pick one',
                    gold: p.supportedCountryCode != null,
                    onTap: () => context.push(RoutePaths.supportedCountry),
                  ),
                  _SettingRow(
                    icon: Icons.emoji_events_outlined,
                    label: 'Tournament awards',
                    onTap: () => context.push(RoutePaths.awardPicks),
                  ),
                ]),
              ),
              const SectionHead(title: 'Notifications'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SettingsGroup(rows: [
                  _SettingRow(
                    icon: Icons.notifications_active_outlined,
                    label: 'Manage alerts',
                    onTap: () => context.push(RoutePaths.notificationPrefs),
                  ),
                ]),
              ),
              const SectionHead(title: 'Privacy & support'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _SettingsGroup(rows: [
                  _SettingRow(
                    icon: Icons.help_outline,
                    label: 'Help centre',
                    onTap: () => context.push(RoutePaths.helpCentre),
                  ),
                  _SettingRow(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy policy',
                    onTap: () => context.push(RoutePaths.privacyPolicy),
                  ),
                  _SettingRow(
                    icon: Icons.gavel_outlined,
                    label: 'Terms of service',
                    onTap: () => context.push(RoutePaths.termsOfService),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GhostButton(
                  label: 'Sign out',
                  expand: true,
                  onPressed: () async {
                    await ref.read(authRepositoryProvider).signOut();
                    ref.invalidate(myProfileProvider);
                    if (context.mounted) context.go('/home');
                  },
                ),
              ),
              const SizedBox(height: 28),
            ],
          );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r5),
          border: Border.all(color: AppColors.borderSoft),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1815), Color(0xFF100E0C)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        ),
        child: Row(
          children: [
            // Centralised: pulls photoUrl from profile (with Firebase
            // fallback) so the hero avatar matches the appbar's.
            const UserAvatar(size: 64, fontSize: 22),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.displayName ?? 'Manager',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.44,
                      color: AppColors.fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Public handle — falls back to email when the user hasn't
                  // claimed a tag yet (legacy accounts pre-userTag rollout).
                  Text(
                    profile.userTag != null
                        ? '@${profile.userTag}'
                        : (profile.email ?? '—'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: profile.userTag != null
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: profile.userTag != null
                          ? AppColors.gold
                          : AppColors.muted,
                      letterSpacing: profile.userTag != null ? -0.2 : 0,
                    ),
                  ),
                  // (Pro / Free pip hidden — Pro tier isn't shipping yet.)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final ProfileStats stats;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Row(
        children: [
          Expanded(child: _Stat(label: 'Cards', value: stats.ownedCards.toString())),
          _Divider(),
          Expanded(child: _Stat(label: 'Total pts', value: stats.totalFantasyPoints.toStringAsFixed(0), gold: true)),
          _Divider(),
          Expanded(child: _Stat(label: '1v1 wins', value: stats.h2hWins.toString())),
          _Divider(),
          Expanded(child: _Stat(label: 'Iconic', value: (stats.rarityCount['ICONIC'] ?? 0).toString())),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: AppColors.borderSoft);
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.gold = false});
  final String label;
  final String value;
  final bool gold;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: gold ? AppColors.gold : AppColors.fg,
            letterSpacing: -0.36,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Eyebrow(label, size: 9),
      ],
    );
  }
}

class _AchvBadge extends StatelessWidget {
  const _AchvBadge(this.a);
  final ProfileAchievement a;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r3),
        gradient: const LinearGradient(
          colors: [Color(0xFFC99A3D), Color(0xFF6F4C18)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        boxShadow: [
          BoxShadow(color: AppColors.goldGlow, blurRadius: 16, spreadRadius: -2),
        ],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: a.iconUrl != null
          ? PremiumImage(url: a.iconUrl, fit: BoxFit.contain)
          : const Icon(Icons.emoji_events, size: 24, color: Color(0xFF1E1810)),
    );
  }
}

class _FollowCard extends StatelessWidget {
  const _FollowCard({required this.team});
  final ProfileTeam team;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r3),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Column(
        children: [
          SizedBox(width: 36, height: 36, child: PremiumImage(url: team.crestUrl, fit: BoxFit.contain)),
          const SizedBox(height: 6),
          Text(
            team.shortName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r3),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) Container(height: 1, color: AppColors.borderSoft),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    this.value,
    this.gold = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String? value;
  final bool gold;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: gold ? AppColors.gold : AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.fg,
              ),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: gold ? AppColors.gold : AppColors.muted,
              ),
            ),
          const SizedBox(width: 6),
          // Chevron only when there's a tap target — otherwise it lies
          // about being tappable.
          if (onTap != null)
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted2)
          else
            const SizedBox(width: 18),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}
