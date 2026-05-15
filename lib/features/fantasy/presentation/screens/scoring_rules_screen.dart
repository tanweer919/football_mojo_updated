import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/repositories/scoring_repository.dart';

/// Public, scrollable explanation of the scoring system. Rendered entirely
/// from the backend's `/v1/scoring/rules` payload — no constants duplicated
/// in mobile code, so rule tweaks ship instantly without app updates.
class ScoringRulesScreen extends ConsumerWidget {
  const ScoringRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scoringRulesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('How scoring works')),
      body: CenteredContent(
        child: async.when(
          loading: () => const SkeletonList(itemHeight: 120),
          error: (e, _) => ErrorView(message: '$e', onRetry: () => ref.invalidate(scoringRulesProvider)),
          data: (rules) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _Intro(rules: rules)
                    .animate().fade(duration: 320.ms).slideY(begin: 0.04, end: 0),
                const SizedBox(height: 16),
                for (var i = 0; i < rules.buckets.length; i++)
                  _BucketCard(bucket: rules.buckets[i], indexInList: i),
                const SizedBox(height: 24),
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: ListTile(
                    leading: Icon(Icons.flag, color: theme.colorScheme.onPrimaryContainer),
                    title: Text('Captain bonus',
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      'Your captain scores ×${rules.total['captainMultiplier']}. Pick wisely.',
                      style: TextStyle(color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.85)),
                    ),
                  ),
                ).animate().fade(duration: 320.ms, delay: 400.ms).slideY(begin: 0.04, end: 0),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.rules});
  final ScoringRules rules;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cap = rules.total['ceiling'];
    final floor = rules.total['floor'];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Every player you pick earns a score between $floor and $cap.',
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            'Points come from three buckets, transparent and stat-based. Stats are sourced live from official match data.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

class _BucketCard extends StatelessWidget {
  const _BucketCard({required this.bucket, required this.indexInList});
  final ScoringBucket bucket;
  final int indexInList;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Expanded(child: Text(bucket.name,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              if (bucket.cap != null)
                _Pill(label: 'max ${bucket.cap!.toStringAsFixed(0)}', color: theme.colorScheme.primaryContainer, onColor: theme.colorScheme.onPrimaryContainer),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(bucket.description,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          children: [
            if (bucket.items != null) _ItemTable(items: bucket.items!),
            if (bucket.weights != null) _WeightsTable(weights: bucket.weights!),
          ],
        ),
      ),
    ).animate().fade(duration: 280.ms, delay: (80 * indexInList).ms).slideY(begin: 0.04, end: 0);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.onColor});
  final String label; final Color color; final Color onColor;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
        child: Text(label, style: TextStyle(color: onColor, fontWeight: FontWeight.w800, fontSize: 11)),
      );
}

class _ItemTable extends StatelessWidget {
  const _ItemTable({required this.items});
  final List<Map<String, dynamic>> items;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: items.map((it) {
        final v = (it['value'] as num).toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(it['label'] as String, style: theme.textTheme.bodyMedium)),
              Text(v >= 0 ? '+${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}' : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1),
                  style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: v >= 0 ? theme.colorScheme.primary : theme.colorScheme.error)),
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
    final theme = Theme.of(context);
    // Two shapes from the API:
    //  A) Map<rule, Map<position, value>>  e.g. goal.GK=12 etc.
    //  B) Map<position, Map<rule, value>>  e.g. GK.savePerOne=1
    //  C) Map<rule, value> (scalar)
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      columnWidths: const {0: FlexColumnWidth()},
      children: weights.entries.map((e) {
        final inner = e.value;
        if (inner is Map) {
          return TableRow(children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(_humanise(e.key),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ),
            ...inner.entries.map((sub) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: _Cell(label: sub.key as String, value: (sub.value as num).toDouble()),
                )),
          ]);
        }
        final v = (inner as num).toDouble();
        return TableRow(children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(_humanise(e.key),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Text(_format(v),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: v >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
                )),
          ),
          const SizedBox.shrink(), const SizedBox.shrink(), const SizedBox.shrink(),
        ]);
      }).toList(),
    );
  }

  String _humanise(String s) =>
      s.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}').replaceAll('_', ' ').toLowerCase();
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});
  final String label; final double value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(_format(value),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: value >= 0 ? theme.colorScheme.primary : theme.colorScheme.error,
              fontFeatures: const [FontFeature.tabularFigures()],
            )),
      ],
    );
  }
}

String _format(double v) {
  final s = v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return v >= 0 ? '+$s' : s;
}
