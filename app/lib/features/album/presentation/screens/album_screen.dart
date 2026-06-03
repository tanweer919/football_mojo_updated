import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/auth/sign_in_sheet.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/empty_states.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/pcard.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../data/models/card_models.dart';
import '../../data/repositories/album_repository.dart';
import '../widgets/free_card_cta.dart';

/// Collection screen — exact port of `design-specs/android/collection.html`.
class AlbumScreen extends ConsumerStatefulWidget {
  const AlbumScreen({super.key});
  @override
  ConsumerState<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends ConsumerState<AlbumScreen> {
  CardRarity? _filter;

  @override
  Widget build(BuildContext context) {
    final album = ref.watch(albumProvider);
    return PitchScreen(
      title: 'Your Collection',
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      trailing: CircleIconButton(icon: Icons.swap_horiz, onPressed: () {}),
      scrollable: false,
      // The inner lists own their bottom inset (below) so content fills
      // edge-to-edge — otherwise PitchScreen reserves a bottom band that
      // shows as a dark bar above the floating tab bar.
      bottomSafeArea: false,
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(albumProvider),
        color: AppColors.gold,
        backgroundColor: AppColors.surface3,
        child: album.when(
          loading: () => GridView.builder(
            padding: EdgeInsets.fromLTRB(16, 16, 16, PitchScreen.bottomInset(context)),
            itemCount: 6,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.66,
            ),
            itemBuilder: (_, __) => const PCardSkeleton(),
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('$e', style: const TextStyle(color: AppColors.live)),
              ),
            ],
          ),
          data: (sets) {
            final allEntries = sets.expand((s) => s.entries).toList();
            final ownedEntries = allEntries.where((e) => e.owned > 0).toList();
            final tierCounts = _tierCounts(allEntries);

            // Empty collection — disambiguate signed-in (no cards yet) vs
            // signed-out (auth required to claim).
            if (allEntries.isEmpty) {
              final authed = ref.watch(authStateProvider).valueOrNull;
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                children: [_EmptyCollection(signedIn: authed != null && !authed.isAnonymous)],
              );
            }

            final featured = ownedEntries.firstWhere(
              (e) => e.template.rarity == CardRarity.ICONIC,
              orElse: () => ownedEntries.firstOrNull ?? allEntries.first,
            );

            final filtered = _filter == null
                ? ownedEntries
                : ownedEntries.where((e) => e.template.rarity == _filter).toList();
            filtered.sort((a, b) => b.template.rarity.index.compareTo(a.template.rarity.index));

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.fromLTRB(0, 8, 0, PitchScreen.bottomInset(context)),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ColHero(featured: featured),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ColStats(
                    owned: ownedEntries.length,
                    iconic: tierCounts[CardRarity.ICONIC] ?? 0,
                    avgRating: _avgRating(ownedEntries),
                  ),
                ),
                const SizedBox(height: 16),
                // Watch-ad-for-card — earn a new card straight into the
                // collection. Hides itself when ads are off or the user is Pro.
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: FreeCardCta(),
                ),
                const SizedBox(height: 22),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Eyebrow('By rarity'),
                      Spacer(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TierTable(tierCounts: tierCounts, allEntries: allEntries),
                ),
                const SizedBox(height: 22),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _RarityFilterChip(
                        label: 'All',
                        count: ownedEntries.length,
                        active: _filter == null,
                        onTap: () => setState(() => _filter = null),
                      ),
                      for (final r in CardRarity.values.reversed)
                        _RarityFilterChip(
                          label: _rarityLabel(r),
                          count: tierCounts[r] ?? 0,
                          active: _filter == r,
                          onTap: () => setState(() => _filter = r),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Eyebrow(_filter == null ? 'Recent · Top rated' : '${_rarityLabel(_filter!)} · ${filtered.length}'),
                ),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      _filter == null
                          ? 'No cards yet — claim your daily reward to start collecting.'
                          : 'No ${_rarityLabel(_filter!).toLowerCase()} cards yet.',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.66,
                      ),
                      itemBuilder: (_, i) {
                        final e = filtered[i];
                        return PCard(
                          rarity: e.template.rarity,
                          rating: _ratingFromTemplate(e.template),
                          name: e.template.playerName?.split(' ').last ?? '—',
                          position: 'PL',
                          country: e.template.teamName?.substring(0, 3).toUpperCase() ?? '—',
                          photoUrl: e.template.artUrl,
                          onTap: e.firstOwnedCardId == null
                              ? null
                              : () => context.push('/album/${e.firstOwnedCardId}'),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _rarityLabel(CardRarity r) => switch (r) {
        CardRarity.COMMON => 'Common',
        CardRarity.UNCOMMON => 'Uncommon',
        CardRarity.RARE => 'Rare',
        CardRarity.EPIC => 'Epic',
        CardRarity.LEGENDARY => 'Legendary',
        CardRarity.ICONIC => 'Iconic',
      };

  Map<CardRarity, int> _tierCounts(List<AlbumEntryDto> entries) {
    final m = <CardRarity, int>{};
    for (final e in entries) {
      if (e.owned == 0) continue;
      m[e.template.rarity] = (m[e.template.rarity] ?? 0) + 1;
    }
    return m;
  }

  int _ratingFromTemplate(CardTemplateDto t) => _ratingForRarity(t.rarity);

  int _ratingForRarity(CardRarity r) => switch (r) {
        CardRarity.COMMON => 75,
        CardRarity.UNCOMMON => 79,
        CardRarity.RARE => 84,
        CardRarity.EPIC => 88,
        CardRarity.LEGENDARY => 92,
        CardRarity.ICONIC => 95,
      };

  double _avgRating(List<AlbumEntryDto> entries) {
    if (entries.isEmpty) return 0;
    final ratings = entries.map((e) => _ratingFromTemplate(e.template).toDouble());
    return ratings.reduce((a, b) => a + b) / entries.length;
  }
}

extension on Iterable<AlbumEntryDto> {
  AlbumEntryDto? get firstOrNull => isEmpty ? null : first;
}

class _EmptyCollection extends ConsumerWidget {
  const _EmptyCollection({required this.signedIn});
  final bool signedIn;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = signedIn
        ? const _CollectionState(
            title: 'Your shelf is fresh',
            subtitle:
                'Claim your free daily card or finish top of a 1v1 ladder to earn your first Iconic. New drops land here automatically.',
            ctaLabel: 'Claim today’s card',
            ctaIcon: Icons.local_fire_department,
          )
        : _CollectionState(
            title: 'Sign in to start collecting',
            subtitle:
                'Cards are tied to your account. Sign in to claim your daily card and unlock the album.',
            ctaLabel: 'Sign in to claim',
            ctaIcon: Icons.g_mobiledata,
            onTap: () async {
              final user = await quickSignIn(context, ref);
              if (user != null) ref.invalidate(albumProvider);
            },
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
      child: body,
    );
  }
}

class _CollectionState extends StatelessWidget {
  const _CollectionState({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    required this.ctaIcon,
    this.onTap,
  });
  final String title;
  final String subtitle;
  final String ctaLabel;
  final IconData ctaIcon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r5),
        border: Border.all(color: AppColors.borderSoft),
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: PitchEmptyState(
        eyebrow: 'Your collection',
        title: title,
        subtitle: subtitle,
        glyph: EmptyGlyph.cards,
        padding: const EdgeInsets.all(28),
      ),
    ).withCta(label: ctaLabel, icon: ctaIcon, onTap: onTap);
  }
}

extension on Widget {
  Widget withCta({required String label, required IconData icon, VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        this,
        const SizedBox(height: 14),
        GoldButton(label: label, icon: icon, expand: true, onPressed: onTap ?? () {}),
      ],
    );
  }
}

// ─── HERO ──────────────────────────────────────────────────────────────────

class _ColHero extends StatelessWidget {
  const _ColHero({required this.featured});
  final AlbumEntryDto featured;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r5),
        border: Border.all(color: const Color(0x66A268D5)),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1432), Color(0xFF0E0716)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.r5),
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0x4DD656B5), Colors.transparent],
                    center: Alignment(1, 1),
                    radius: 0.8,
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x4DD656B5),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0x66D656B5)),
                ),
                child: Eyebrow('${_label(featured.template.rarity)} · 1 of 1', size: 10, color: const Color(0xFFD2B0F0)),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    child: PCard(
                      rarity: featured.template.rarity,
                      rating: _ratingForRarity(featured.template.rarity),
                      name: featured.template.playerName?.split(' ').last ?? '—',
                      position: 'PL',
                      country: featured.template.teamName?.substring(0, 3).toUpperCase() ?? '—',
                      photoUrl: featured.template.artUrl,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Eyebrow('Crown jewel', color: Color(0xFFD2B0F0)),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.77,
                              color: AppColors.fg,
                              height: 1.0,
                            ),
                            children: [
                              const TextSpan(text: 'The pride of\nyour '),
                              TextSpan(
                                text: 'collection.',
                                style: const TextStyle(
                                  fontFamily: 'IowanOldStyle',
                                  fontFamilyFallback: ['Charter', 'Georgia', 'serif'],
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFD2B0F0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Eyebrow('Serial #${featured.firstOwnedCardId?.substring(0, 4) ?? '0001'}', gold: true),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _label(CardRarity r) => switch (r) {
        CardRarity.COMMON => 'Common',
        CardRarity.UNCOMMON => 'Uncommon',
        CardRarity.RARE => 'Rare',
        CardRarity.EPIC => 'Epic',
        CardRarity.LEGENDARY => 'Legendary',
        CardRarity.ICONIC => 'Iconic',
      };

  int _ratingForRarity(CardRarity r) => switch (r) {
        CardRarity.COMMON => 75,
        CardRarity.UNCOMMON => 79,
        CardRarity.RARE => 84,
        CardRarity.EPIC => 88,
        CardRarity.LEGENDARY => 92,
        CardRarity.ICONIC => 95,
      };
}

// ─── STATS ─────────────────────────────────────────────────────────────────

class _ColStats extends StatelessWidget {
  const _ColStats({required this.owned, required this.iconic, required this.avgRating});
  final int owned;
  final int iconic;
  final double avgRating;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _StatCol(value: owned.toString(), label: 'Owned')),
          _Divider(),
          Expanded(child: _StatCol(value: iconic.toString(), label: 'Iconic', gold: true)),
          _Divider(),
          Expanded(child: _StatCol(value: avgRating.toStringAsFixed(1), label: 'Avg rating')),
          _Divider(),
          const Expanded(child: _StatCol(value: '↑0', label: 'This wk')),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppColors.borderSoft);
}

class _StatCol extends StatelessWidget {
  const _StatCol({required this.value, required this.label, this.gold = false});
  final String value;
  final String label;
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

// ─── TIER TABLE ────────────────────────────────────────────────────────────

class _TierTable extends StatelessWidget {
  const _TierTable({required this.tierCounts, required this.allEntries});
  final Map<CardRarity, int> tierCounts;
  final List<AlbumEntryDto> allEntries;
  @override
  Widget build(BuildContext context) {
    final tiers = <(CardRarity, String, Color)>[
      (CardRarity.ICONIC, 'Iconic', const Color(0xFFD656B5)),
      (CardRarity.LEGENDARY, 'Legendary', AppColors.gold),
      (CardRarity.EPIC, 'Epic', AppColors.rEpic),
      (CardRarity.RARE, 'Rare', AppColors.rRare),
      (CardRarity.COMMON, 'Common', AppColors.rCommon),
    ];
    return Column(
      children: [
        for (final (rarity, label, color) in tiers)
          _TierRow(
            label: label,
            color: color,
            owned: tierCounts[rarity] ?? 0,
            total: allEntries.where((e) => e.template.rarity == rarity).length,
          ),
      ],
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.label,
    required this.color,
    required this.owned,
    required this.total,
  });
  final String label;
  final Color color;
  final int owned;
  final int total;
  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : owned / total;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSoft, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Eyebrow(label, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: Stack(
                children: [
                  Container(height: 4, color: AppColors.surface3),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(height: 4, color: color),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 50,
            child: Text(
              '$owned / $total',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 11,
                color: AppColors.fg,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RarityFilterChip extends StatelessWidget {
  const _RarityFilterChip({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: active ? AppColors.goldHairline : AppColors.borderSoft),
            gradient: active
                ? const LinearGradient(
                    colors: [AppColors.surface3, AppColors.surface2],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter)
                : null,
            color: active ? null : AppColors.surface,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Eyebrow(label, color: active ? AppColors.gold : AppColors.muted, size: 10),
              const SizedBox(width: 6),
              Text(
                count.toString(),
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.gold.withValues(alpha: 0.6) : AppColors.muted2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
