import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/eyebrow.dart';

/// Score color shared by form hex, performance bars, and grid badges.
Color scoreColor(double v) {
  if (v >= 60) return AppColors.pitch;
  if (v >= 30) return AppColors.gold;
  if (v >= 0) return AppColors.fgSoft;
  return AppColors.live;
}

// ─── Compact score hex badge (for grid tiles) ─────────────────────────────

/// Small hexagonal-style score badge used below each card in the market grid.
class ScoreHexBadge extends StatelessWidget {
  const ScoreHexBadge({super.key, required this.score, this.size = 28});
  final double score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = scoreColor(score);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: c.withValues(alpha: 0.5), width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        score.toStringAsFixed(0),
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: c,
          height: 1.0,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Larger form hex for detail screens — circle with glow.
class FormHexLarge extends StatelessWidget {
  const FormHexLarge({super.key, required this.score, required this.n, this.size = 56});
  final double score;
  final int n;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasData = n > 0;
    final c = hasData ? scoreColor(score) : AppColors.muted2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: c.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.2), blurRadius: 12)],
      ),
      alignment: Alignment.center,
      child: Text(
        hasData ? score.toStringAsFixed(0) : '—',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: c,
          letterSpacing: -0.4,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ─── Form stats panel (Last 5 / 10 / 40) ─────────────────────────────────

/// Three-column form stats panel matching Sorare's "Stats" section.
/// Accepts generic triples so both market and album screens can use it.
class PlayerFormPanel extends StatelessWidget {
  const PlayerFormPanel({
    super.key,
    required this.last5Avg,
    required this.last5N,
    required this.last10Avg,
    required this.last10N,
    required this.last40Avg,
    required this.last40N,
  });
  final double last5Avg;
  final int last5N;
  final double last10Avg;
  final int last10N;
  final double last40Avg;
  final int last40N;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: Row(
        children: [
          Expanded(child: _FormColumn(label: 'Last 5', avg: last5Avg, n: last5N)),
          Container(width: 1, height: 80, color: AppColors.borderSoft),
          Expanded(child: _FormColumn(label: 'Last 10', avg: last10Avg, n: last10N)),
          Container(width: 1, height: 80, color: AppColors.borderSoft),
          Expanded(child: _FormColumn(label: 'Last 40', avg: last40Avg, n: last40N)),
        ],
      ),
    );
  }
}

class _FormColumn extends StatelessWidget {
  const _FormColumn({required this.label, required this.avg, required this.n});
  final String label;
  final double avg;
  final int n;

  @override
  Widget build(BuildContext context) {
    final hasData = n > 0;
    final pct = hasData ? '${(n > 0 ? 100 : 0).clamp(0, 100)}%' : '';
    return Column(
      children: [
        Eyebrow(label, size: 9),
        const SizedBox(height: 8),
        FormHexLarge(score: avg, n: n),
        const SizedBox(height: 6),
        if (hasData)
          Text(
            pct,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scoreColor(avg),
              letterSpacing: -0.1,
            ),
          )
        else
          const Text(
            'no data',
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
            ),
          ),
      ],
    );
  }
}

// ─── Performance bars ─────────────────────────────────────────────────────

/// Per-gameweek performance bar chart. Generic — works with both market
/// and album score types via a simple data class.
class PerformanceBarData {
  const PerformanceBarData({
    required this.totalPoints,
    this.gameweekNumber,
    this.breakdown,
  });
  final double totalPoints;
  final int? gameweekNumber;
  final dynamic breakdown;
}

class PerformanceBarsPanel extends StatelessWidget {
  const PerformanceBarsPanel({super.key, required this.scores});
  final List<PerformanceBarData> scores;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) return const SizedBox.shrink();
    // Chronological L→R: latest on the right.
    final ordered = scores.reversed.toList();
    final maxAbs = ordered
        .map((s) => s.totalPoints.abs())
        .fold<double>(0, (m, v) => v > m ? v : m)
        .clamp(20.0, 100.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.borderSoft),
        color: AppColors.surface2,
      ),
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final s in ordered)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: _Bar(score: s, maxAbs: maxAbs),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.score, required this.maxAbs});
  final PerformanceBarData score;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    final c = scoreColor(score.totalPoints);
    final barH = (score.totalPoints.abs() / maxAbs * 80).clamp(4.0, 80.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Score value
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            score.totalPoints.toStringAsFixed(0),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: c,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 3),
        // The bar
        Container(
          width: 20,
          height: barH,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [c.withValues(alpha: 0.35), c.withValues(alpha: 0.15)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            border: Border.all(color: c.withValues(alpha: 0.5), width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 3),
        // Goal/assist icons
        _BarIcons(breakdown: score.breakdown),
        const SizedBox(height: 3),
        // GW label
        Text(
          score.gameweekNumber == null ? '·' : 'GW${score.gameweekNumber}',
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
            fontSize: 7.5,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _BarIcons extends StatelessWidget {
  const _BarIcons({required this.breakdown});
  final dynamic breakdown;

  @override
  Widget build(BuildContext context) {
    int goals = 0, assists = 0;
    if (breakdown is List) {
      for (final entry in breakdown as List) {
        if (entry is! Map) continue;
        final k = entry['key'] as String?;
        final count = (entry['count'] as num?)?.toInt() ?? 0;
        if (k == 'goal' || k == 'penaltyGoal') goals += count;
        if (k == 'assist') assists += count;
      }
    }
    if (goals == 0 && assists == 0) return const SizedBox(height: 12);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < goals; i++)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 0.5),
            child: Icon(Icons.sports_soccer, size: 9, color: AppColors.pitch),
          ),
        for (var i = 0; i < assists; i++)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 0.5),
            child: Icon(Icons.compare_arrows, size: 9, color: AppColors.gold),
          ),
      ],
    );
  }
}
