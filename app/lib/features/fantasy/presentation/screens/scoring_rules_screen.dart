import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/pitch_scaffold.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/repositories/scoring_repository.dart';

/// Full scoring guide. Rendered entirely from `/v1/scoring/rules` — no
/// constants duplicated in mobile code, so rule tweaks ship instantly
/// without an app update.
///
/// Layout:
///   - Squad rules (composition + budget)
///   - Scoring buckets (Appearance / All-Around / Decisive / Position)
///   - Captain multiplier
///   - Owned-card bonus (computed client-side; explained below)
class ScoringRulesScreen extends ConsumerWidget {
  const ScoringRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scoringRulesProvider);
    return PitchScreen(
      title: 'How scoring works',
      scrollable: false,
      onBack: () => context.canPop() ? context.pop() : context.go('/fantasy'),
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: Skeleton(height: 200, radius: 16),
        ),
        error: (e, _) => ErrorView(
          message: '$e',
          onRetry: () => ref.invalidate(scoringRulesProvider),
        ),
        data: (rules) {
          final squad = (rules.squad as Map?)?.cast<String, dynamic>() ?? const {};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              _IntroPanel(rules: rules),
              const SizedBox(height: 14),
              _SquadPanel(squad: squad),
              const SizedBox(height: 14),
              const _SectionTitle('Scoring buckets'),
              for (var i = 0; i < rules.buckets.length; i++) ...[
                const SizedBox(height: 10),
                _BucketCard(bucket: rules.buckets[i]),
              ],
              const SizedBox(height: 20),
              const _SectionTitle('Multipliers'),
              const SizedBox(height: 10),
              _CaptainPanel(multiplier: rules.total['captainMultiplier']),
              const SizedBox(height: 10),
              const _OwnedCardPanel(),
              const SizedBox(height: 24),
              GhostButton(
                label: 'View live leaderboard',
                onPressed: () => context.go('/predictions/leaderboard'),
                expand: true,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Intro ──────────────────────────────────────────────────────────────

class _IntroPanel extends StatelessWidget {
  const _IntroPanel({required this.rules});
  final ScoringRules rules;
  @override
  Widget build(BuildContext context) {
    final cap = rules.total['ceiling'];
    final floor = rules.total['floor'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.goldHairline),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1814), Color(0xFF110C09)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Transparent scoring', gold: true, size: 11),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.32,
                color: AppColors.fg,
                height: 1.25,
              ),
              children: [
                const TextSpan(text: 'Every player scores '),
                TextSpan(
                  text: '$floor to $cap',
                  style: const TextStyle(color: AppColors.gold),
                ),
                const TextSpan(text: ' points per match.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Points come from three transparent buckets, sourced from live match data. No hidden formulas — every contribution is shown below.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Squad / Budget ────────────────────────────────────────────────────

class _SquadPanel extends StatelessWidget {
  const _SquadPanel({required this.squad});
  final Map<String, dynamic> squad;
  @override
  Widget build(BuildContext context) {
    final size = squad['size'] ?? 5;
    final budget = squad['budget'] ?? 100;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('Squad', gold: true, size: 10),
          const SizedBox(height: 8),
          Row(
            children: [
              _KpiCell(value: '$size', label: 'Picks'),
              const _Divider(),
              _KpiCell(value: '$budget', label: 'Budget'),
              const _Divider(),
              const _KpiCell(value: '1', label: 'Captain'),
              const _Divider(),
              const _KpiCell(value: '×2', label: 'Mult.', gold: true),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '5-a-side format: exactly 1 GK, at least 1 DEF / 1 MID / 1 FWD, plus a free UTL slot (any outfield).',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: AppColors.muted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bucket card (Appearance / All-Around / Decisive / Position) ──────

class _BucketCard extends StatefulWidget {
  const _BucketCard({required this.bucket});
  final ScoringBucket bucket;
  @override
  State<_BucketCard> createState() => _BucketCardState();
}

class _BucketCardState extends State<_BucketCard> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadii.r4),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.bucket.name,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: AppColors.fg,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.bucket.description,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            color: AppColors.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.bucket.cap != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppColors.goldHairline),
                      ),
                      child: Text(
                        'max ${widget.bucket.cap!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_open) ...[
            Container(height: 1, color: AppColors.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: widget.bucket.items != null
                  ? _ItemList(items: widget.bucket.items!)
                  : widget.bucket.weights != null
                      ? _WeightsTable(weights: widget.bucket.weights!)
                      : const SizedBox.shrink(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: items.map((it) {
        final v = (it['value'] as num).toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  it['label'] as String,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.fgSoft,
                  ),
                ),
              ),
              _PointsPill(value: v),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _WeightsTable extends StatelessWidget {
  const _WeightsTable({required this.weights});
  final Map<String, dynamic> weights;
  @override
  Widget build(BuildContext context) {
    // Two shapes from the API:
    //  A) Map<rule, Map<position, value>>  e.g. goal.GK=12 etc.
    //  B) Map<position, Map<rule, value>>  e.g. GK.savePerOne=1
    //  C) Map<rule, value> (scalar)
    return Column(
      children: weights.entries.map((e) {
        final inner = e.value;
        if (inner is Map) {
          // Inner map — render rule + per-bucket sub-values.
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _humanise(e.key),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.fg,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: inner.entries.map((sub) {
                    final v = (sub.value as num).toDouble();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface3,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderSoft),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${sub.key}',
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.muted,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _PointsPill(value: v, compact: true),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }
        // Scalar value — single rule + single number.
        final v = (inner as num).toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _humanise(e.key),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.fgSoft,
                  ),
                ),
              ),
              _PointsPill(value: v),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _humanise(String s) =>
      s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
          .replaceAll('_', ' ')
          .replaceFirstMapped(RegExp(r'^.'), (m) => m[0]!.toUpperCase());
}

class _PointsPill extends StatelessWidget {
  const _PointsPill({required this.value, this.compact = false});
  final double value;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final pos = value >= 0;
    final s = value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 1 : 2),
      decoration: BoxDecoration(
        color: pos
            ? AppColors.pitch.withValues(alpha: 0.15)
            : AppColors.live.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        pos ? '+$s' : s,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w800,
          color: pos ? AppColors.pitch : AppColors.live,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─── Captain / Owned-card multipliers ─────────────────────────────────

class _CaptainPanel extends StatelessWidget {
  const _CaptainPanel({required this.multiplier});
  final dynamic multiplier;
  @override
  Widget build(BuildContext context) {
    return _MultiplierPanel(
      icon: Icons.shield,
      title: 'Captain bonus',
      subtitle: 'Your captain\'s points are multiplied by ${multiplier ?? 2}. Pick wisely — the difference between a winning lineup and an also-ran is almost always your armband choice.',
      badge: '×${multiplier ?? 2}',
    );
  }
}

class _OwnedCardPanel extends StatelessWidget {
  const _OwnedCardPanel();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.goldHairline),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1814), Color(0xFF110C09)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.style, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              const Eyebrow('Owned-card bonus', gold: true, size: 10),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.16),
                  border: Border.all(color: AppColors.goldHairline),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'NEW',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Pick a player whose card you own → their points get an additional multiplier on top of any captain bonus. Higher-rarity cards = bigger bonus.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.fgSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          const _BonusGrid(),
          const SizedBox(height: 10),
          const Text(
            'Stacks with captain (×2). E.g. an Iconic card captain scores ×2 × ×1.6 = ×3.2.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BonusGrid extends StatelessWidget {
  const _BonusGrid();
  // Source of truth for the multipliers — see backend
  // `OWNED_CARD_MULTIPLIER` in fantasy.constants.ts. Mirrored here for
  // the scoring guide display. If you change one, change both.
  static const _rows = [
    ('COMMON', '×1.10'),
    ('UNCOMMON', '×1.12'),
    ('RARE', '×1.15'),
    ('EPIC', '×1.25'),
    ('LEGENDARY', '×1.40'),
    ('ICONIC', '×1.60'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _rows.map((r) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              r.$1,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.muted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              r.$2,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.gold,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }
}

class _MultiplierPanel extends StatelessWidget {
  const _MultiplierPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.16),
              border: Border.all(color: AppColors.goldHairline),
            ),
            child: Icon(icon, size: 18, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.fg,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: AppColors.muted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            badge,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, top: 8, bottom: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.fg,
            letterSpacing: -0.24,
          ),
        ),
      );
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({required this.value, required this.label, this.gold = false});
  final String value;
  final String label;
  final bool gold;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
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
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppColors.borderSoft);
}
