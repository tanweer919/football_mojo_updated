import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pcard.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../../market/presentation/widgets/player_form_widgets.dart';
import '../../../profile/data/profile_repository.dart';
import '../../data/models/card_models.dart';

/// Rich detail page for a single OwnedCard — modelled on Sorare's player
/// page. Three blocks:
///   1. Hero — the card itself, prominent serial chip + level pill
///   2. Form widget — Last 5 / 10 / 40 average scores with sample sizes
///   3. Performance bars — per-gameweek score with goal/assist icons
///   4. Provenance — mint context + first owner + sister copies
///   5. Showcase toggle — pin / unpin from profile
class OwnedCardStatsScreen extends ConsumerWidget {
  const OwnedCardStatsScreen({super.key, required this.ownedCardId});
  final String ownedCardId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ownedCardDetailProvider(ownedCardId));
    return PitchScreen(
      title: 'Card detail',
      onBack: () => context.canPop() ? context.pop() : context.go('/album'),
      child: async.when(
        loading: () => const _DetailSkeleton(),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$e', style: const TextStyle(color: AppColors.live)),
        ),
        data: (d) => _DetailBody(detail: d),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});
  final OwnedCardDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = detail.template;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        // 1. Hero — the card itself, sized for prominence on the page.
        // CardTemplateDto has flat playerName/teamName/teamCrestUrl
        // — no nested `player` object on the album DTO surface.
        Center(
          child: SizedBox(
            width: 240,
            child: PCard(
              rarity: t.rarity,
              rating: _ratingFor(t.rarity),
              name: t.playerName,
              photoUrl: t.artUrl,
              clubCrestUrl: t.teamCrestUrl,
              leagueLabel: _shortEdition(t.edition),
              editionLabel: t.edition,
              serialNumber: detail.serialNumber,
              totalSupply: t.totalSupply,
              level: detail.level,
              trophies: detail.trophies.length,
              heroTag: 'owned-${detail.id}',
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Name + serial + level meta.
        Center(
          child: Column(
            children: [
              Text(
                t.playerName ?? '—',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.44,
                  color: AppColors.fg,
                ),
              ),
              const SizedBox(height: 4),
              Eyebrow(
                '${detail.serialNumber} / ${t.totalSupply} · LEVEL ${detail.level} · ${detail.xp} XP',
                gold: true,
                size: 10,
              ),
            ],
          ),
        ),
        // 2. Form stats — Last 5/10/40.
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PlayerFormPanel(
            last5Avg: detail.formStats.last5.avg,
            last5N: detail.formStats.last5.n,
            last10Avg: detail.formStats.last10.avg,
            last10N: detail.formStats.last10.n,
            last40Avg: detail.formStats.last40.avg,
            last40N: detail.formStats.last40.n,
          ),
        ),
        // 3. Performance bars — per-gameweek scores.
        if (detail.lastScores.isNotEmpty) ...[
          const SectionHead(title: 'Performance', padding: EdgeInsets.fromLTRB(20, 20, 20, 8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PerformanceBarsPanel(
              scores: detail.lastScores
                  .map((s) => PerformanceBarData(
                        totalPoints: s.totalPoints,
                        gameweekNumber: s.gameweekNumber,
                        breakdown: s.breakdown,
                      ))
                  .toList(),
            ),
          ),
        ],
        // 4. Provenance / mint context.
        const SectionHead(title: 'Origin', padding: EdgeInsets.fromLTRB(20, 24, 20, 8)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _ProvenancePanel(detail: detail),
        ),
        // 5. Lifetime stats — what's accrued while owned.
        if (detail.lifetimeApps > 0 || detail.xp > 0) ...[
          const SectionHead(title: 'While you owned it', padding: EdgeInsets.fromLTRB(20, 24, 20, 8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _LifetimePanel(detail: detail),
          ),
        ],
        // 6. Sister copies — other copies of this template the user owns.
        if (detail.sisters.isNotEmpty) ...[
          const SectionHead(title: 'Your other copies', padding: EdgeInsets.fromLTRB(20, 24, 20, 8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SisterCopies(sisters: detail.sisters, total: t.totalSupply),
          ),
        ],
        // 7. Pin / unpin showcase action.
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PinButton(ownedCardId: detail.id),
        ),
        SizedBox(height: 32 + MediaQuery.viewPaddingOf(context).bottom),
      ],
    );
  }

  static int _ratingFor(CardRarity r) => switch (r) {
        CardRarity.COMMON => 75,
        CardRarity.UNCOMMON => 79,
        CardRarity.RARE => 84,
        CardRarity.EPIC => 88,
        CardRarity.LEGENDARY => 92,
        CardRarity.ICONIC => 95,
      };

  static String _shortEdition(String edition) {
    final dash = edition.indexOf('-');
    return dash < 0 ? edition : edition.substring(0, dash);
  }
}


class _VRule extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 56, color: AppColors.borderSoft);
}

// ─── Provenance panel ────────────────────────────────────────────────────

class _ProvenancePanel extends StatelessWidget {
  const _ProvenancePanel({required this.detail});
  final OwnedCardDetail detail;
  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM yyyy');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Row(label: 'Minted', value: fmt.format(detail.mintedAt.toLocal())),
          _Row(label: 'Source', value: _prettySource(detail.acquiredVia)),
          if (detail.mintReason != null && detail.mintReason!.isNotEmpty)
            _Row(label: 'Reason', value: detail.mintReason!, valueColor: AppColors.gold),
          if (detail.firstOwner != null)
            _Row(
              label: 'First owner',
              value: detail.firstOwner!.tag != null
                  ? '@${detail.firstOwner!.tag}'
                  : (detail.firstOwner!.displayName ?? '—'),
            ),
          if (detail.trophies.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Eyebrow('Trophies', gold: true, size: 9),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in detail.trophies) _TrophyPill(code: t),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TrophyPill extends StatelessWidget {
  const _TrophyPill({required this.code});
  final String code;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.goldHairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, size: 11, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(
            _prettyTrophy(code),
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }

  String _prettyTrophy(String code) {
    if (code.startsWith('SET:')) return 'Set Master · ${code.substring(4)}';
    if (code.startsWith('GC_WIN:')) {
      final parts = code.split(':');
      return 'Global Cup winner · GW${parts.length > 2 ? parts[2] : ''}';
    }
    return code;
  }
}

class _LifetimePanel extends StatelessWidget {
  const _LifetimePanel({required this.detail});
  final OwnedCardDetail detail;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.goldHairline),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1815), Color(0xFF110C09)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          Expanded(child: _LifetimeStat(label: 'Apps', value: '${detail.lifetimeApps}')),
          _VRule(),
          Expanded(child: _LifetimeStat(label: 'Goals', value: '${detail.lifetimeGoals}', gold: true)),
          _VRule(),
          Expanded(child: _LifetimeStat(label: 'Assists', value: '${detail.lifetimeAssists}')),
          _VRule(),
          Expanded(child: _LifetimeStat(label: 'Minutes', value: '${detail.lifetimeMinutes}')),
        ],
      ),
    );
  }
}

class _LifetimeStat extends StatelessWidget {
  const _LifetimeStat({required this.label, required this.value, this.gold = false});
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
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: gold ? AppColors.gold : AppColors.fg,
            letterSpacing: -0.4,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Eyebrow(label, size: 9),
      ],
    );
  }
}

// ─── Sister copies ───────────────────────────────────────────────────────

class _SisterCopies extends StatelessWidget {
  const _SisterCopies({required this.sisters, required this.total});
  final List<OwnedCardSister> sisters;
  final int total;
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in sisters)
          GestureDetector(
            onTap: () => context.push('/album/${s.id}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.borderSoft),
              ),
              child: Text(
                '#${s.serialNumber} / $total',
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Pin button ──────────────────────────────────────────────────────────

class _PinButton extends ConsumerStatefulWidget {
  const _PinButton({required this.ownedCardId});
  final String ownedCardId;
  @override
  ConsumerState<_PinButton> createState() => _PinButtonState();
}

class _PinButtonState extends ConsumerState<_PinButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).valueOrNull;
    final isPinned = profile?.pinnedCard?.id == widget.ownedCardId;
    return GoldButton(
      label: isPinned ? 'Unpin from profile' : 'Pin to profile showcase',
      icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
      expand: true,
      onPressed: _busy ? null : () => _toggle(isPinned),
    );
  }

  Future<void> _toggle(bool isPinned) async {
    setState(() => _busy = true);
    try {
      final dio = ref.read(dioProvider);
      if (isPinned) {
        await dio.post<void>('/v1/cards/owned/pin/clear');
      } else {
        await dio.post<void>('/v1/cards/owned/${widget.ownedCardId}/pin');
      }
      ref.invalidate(myProfileProvider);
    } catch (_) {
      // swallow — profile invalidation will recover on next refresh.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Eyebrow(label, size: 9),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.fg,
                letterSpacing: -0.13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Center(child: Skeleton(height: 320, width: 220, radius: 16)),
          SizedBox(height: 16),
          Skeleton(height: 100, radius: 16),
          SizedBox(height: 12),
          Skeleton(height: 160, radius: 16),
        ],
      ),
    );
  }
}

class SectionHead extends StatelessWidget {
  const SectionHead({super.key, required this.title, this.padding = const EdgeInsets.fromLTRB(20, 24, 20, 14)});
  final String title;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.24,
          color: AppColors.fg,
        ),
      ),
    );
  }
}

String _prettySource(String s) => switch (s) {
      'SIGNUP_GIFT'       => 'Signup gift',
      'DAILY_LOGIN'       => 'Daily login',
      'PREDICTION_REWARD' => 'Prediction reward',
      'ACHIEVEMENT'       => 'Achievement',
      'REWARDED_AD'       => 'Rewarded ad',
      'SET_COMPLETION'    => 'Set Master',
      'TRADE'             => 'Trade',
      'DIRECT_PURCHASE'   => 'Direct purchase',
      'ADMIN_GRANT'       => 'Admin grant',
      _                   => s.isEmpty ? '—' : s,
    };

// ─── DTOs + provider ─────────────────────────────────────────────────────

class OwnedCardDetail {
  const OwnedCardDetail({
    required this.id,
    required this.serialNumber,
    required this.template,
    required this.mintedAt,
    required this.acquiredVia,
    required this.lifetimeApps,
    required this.lifetimeGoals,
    required this.lifetimeAssists,
    required this.lifetimeMinutes,
    required this.xp,
    required this.level,
    required this.trophies,
    required this.firstOwner,
    required this.lastScores,
    required this.formStats,
    required this.sisters,
    this.mintReason,
  });
  final String id;
  final int serialNumber;
  final CardTemplateDto template;
  final DateTime mintedAt;
  final String acquiredVia;
  final String? mintReason;
  final int lifetimeApps;
  final int lifetimeGoals;
  final int lifetimeAssists;
  final int lifetimeMinutes;
  final int xp;
  final int level;
  final List<String> trophies;
  final OwnedCardOwner? firstOwner;
  final List<OwnedCardScore> lastScores;
  final OwnedCardFormStats formStats;
  final List<OwnedCardSister> sisters;

  factory OwnedCardDetail.fromJson(Map<String, dynamic> j) => OwnedCardDetail(
        id: j['id'] as String,
        serialNumber: (j['serialNumber'] as num).toInt(),
        template: CardTemplateDto.fromJson((j['template'] as Map).cast<String, dynamic>()),
        mintedAt: DateTime.parse(j['mintedAt'] as String),
        acquiredVia: (j['acquiredVia'] as String?) ?? 'SIGNUP_GIFT',
        mintReason: j['mintReason'] as String?,
        lifetimeApps: (j['lifetimeApps'] as num?)?.toInt() ?? 0,
        lifetimeGoals: (j['lifetimeGoals'] as num?)?.toInt() ?? 0,
        lifetimeAssists: (j['lifetimeAssists'] as num?)?.toInt() ?? 0,
        lifetimeMinutes: (j['lifetimeMinutes'] as num?)?.toInt() ?? 0,
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        level: (j['level'] as num?)?.toInt() ?? 0,
        trophies: ((j['trophies'] as List?) ?? const []).cast<String>(),
        firstOwner: j['firstOwner'] == null
            ? null
            : OwnedCardOwner.fromJson((j['firstOwner'] as Map).cast<String, dynamic>()),
        lastScores: ((j['lastScores'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(OwnedCardScore.fromJson)
            .toList(),
        formStats: OwnedCardFormStats.fromJson((j['formStats'] as Map).cast<String, dynamic>()),
        sisters: ((j['sisters'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(OwnedCardSister.fromJson)
            .toList(),
      );
}

class OwnedCardOwner {
  const OwnedCardOwner({required this.id, this.displayName, this.tag, this.photoUrl});
  final String id;
  final String? displayName;
  final String? tag;
  final String? photoUrl;
  factory OwnedCardOwner.fromJson(Map<String, dynamic> j) => OwnedCardOwner(
        id: j['id'] as String,
        displayName: j['displayName'] as String?,
        tag: j['userTag'] as String?,
        photoUrl: j['photoUrl'] as String?,
      );
}

class OwnedCardScore {
  const OwnedCardScore({
    required this.gameweekId,
    required this.totalPoints,
    this.gameweekNumber,
    this.allAround = 0,
    this.decisive = 0,
    this.position = 0,
    this.breakdown,
  });
  final String gameweekId;
  final int? gameweekNumber;
  final double totalPoints;
  final double allAround;
  final double decisive;
  final double position;
  final dynamic breakdown;
  factory OwnedCardScore.fromJson(Map<String, dynamic> j) => OwnedCardScore(
        gameweekId: j['gameweekId'] as String,
        gameweekNumber: (j['gameweekNumber'] as num?)?.toInt(),
        totalPoints: ((j['totalPoints'] as num?) ?? 0).toDouble(),
        allAround: ((j['allAround'] as num?) ?? 0).toDouble(),
        decisive: ((j['decisive'] as num?) ?? 0).toDouble(),
        position: ((j['position'] as num?) ?? 0).toDouble(),
        breakdown: j['breakdown'],
      );
}

class OwnedCardFormBucket {
  const OwnedCardFormBucket({required this.avg, required this.n});
  final double avg;
  final int n;
  factory OwnedCardFormBucket.fromJson(Map<String, dynamic> j) => OwnedCardFormBucket(
        avg: ((j['avg'] as num?) ?? 0).toDouble(),
        n: (j['n'] as num?)?.toInt() ?? 0,
      );
}

class OwnedCardFormStats {
  const OwnedCardFormStats({required this.last5, required this.last10, required this.last40});
  final OwnedCardFormBucket last5;
  final OwnedCardFormBucket last10;
  final OwnedCardFormBucket last40;
  factory OwnedCardFormStats.fromJson(Map<String, dynamic> j) => OwnedCardFormStats(
        last5: OwnedCardFormBucket.fromJson((j['last5'] as Map).cast<String, dynamic>()),
        last10: OwnedCardFormBucket.fromJson((j['last10'] as Map).cast<String, dynamic>()),
        last40: OwnedCardFormBucket.fromJson((j['last40'] as Map).cast<String, dynamic>()),
      );
}

class OwnedCardSister {
  const OwnedCardSister({required this.id, required this.serialNumber, required this.xp, required this.mintedAt});
  final String id;
  final int serialNumber;
  final int xp;
  final DateTime mintedAt;
  factory OwnedCardSister.fromJson(Map<String, dynamic> j) => OwnedCardSister(
        id: j['id'] as String,
        serialNumber: (j['serialNumber'] as num).toInt(),
        xp: (j['xp'] as num?)?.toInt() ?? 0,
        mintedAt: DateTime.parse(j['mintedAt'] as String),
      );
}

final ownedCardDetailProvider = FutureProvider.family<OwnedCardDetail, String>(
  (ref, id) async {
    final dio = ref.read(dioProvider);
    final res = await dio.get<Map<String, dynamic>>('/v1/cards/owned/$id');
    return OwnedCardDetail.fromJson(res.data!);
  },
);
