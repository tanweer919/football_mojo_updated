import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../predictions/data/predictions_repository.dart';

/// Knockout bracket predictor. Picks per round are pure UI state until "Save".
/// The data shape mirrors the backend Bracket model: { "R16-1": "ARG", ... }.
class BracketScreen extends ConsumerStatefulWidget {
  const BracketScreen({super.key, this.competitionId = 'WC2026'});
  final String competitionId;
  @override
  ConsumerState<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends ConsumerState<BracketScreen> {
  final Map<String, String> _picks = {};
  bool _saving = false;

  // WC 2026 format: 48 teams → 32 qualify (top 2 + 8 best 3rd-placed) → R32 → R16 → QF → SF → Final + 3rd-place playoff.
  static const _r32 = 16;
  static const _r16 = 8;
  static const _qf  = 4;
  static const _sf  = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My bracket'),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(_saving ? 'Saving…' : 'Save'),
            onPressed: _saving ? null : _save,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _RoundSection(title: 'Round of 32',   count: _r32, prefix: 'R32', picks: _picks, onPick: _onPick),
          const SizedBox(height: 16),
          _RoundSection(title: 'Round of 16',   count: _r16, prefix: 'R16', picks: _picks, onPick: _onPick),
          const SizedBox(height: 16),
          _RoundSection(title: 'Quarter-finals', count: _qf, prefix: 'QF',  picks: _picks, onPick: _onPick),
          const SizedBox(height: 16),
          _RoundSection(title: 'Semi-finals',   count: _sf,  prefix: 'SF',  picks: _picks, onPick: _onPick),
          const SizedBox(height: 16),
          _RoundSection(title: 'Third-place playoff', count: 1, prefix: '3RD', picks: _picks, onPick: _onPick),
          const SizedBox(height: 16),
          _RoundSection(title: 'Final',         count: 1,    prefix: 'FIN', picks: _picks, onPick: _onPick),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Pick a winner for each match. Brackets lock at the first knockout kickoff.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  void _onPick(String key, String pick) => setState(() => _picks[key] = pick);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(predictionsRepositoryProvider).submitBracket(widget.competitionId, _picks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bracket saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _RoundSection extends StatelessWidget {
  const _RoundSection({
    required this.title,
    required this.count,
    required this.prefix,
    required this.picks,
    required this.onPick,
  });
  final String title;
  final int count;
  final String prefix;
  final Map<String, String> picks;
  final void Function(String key, String pick) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...List.generate(count, (i) {
          final key = '$prefix-${i + 1}';
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Text('Match ${i + 1}', style: theme.textTheme.labelMedium),
                  const Spacer(),
                  _PickButton(
                    label: 'A',
                    selected: picks[key] == 'A',
                    onTap: () => onPick(key, 'A'),
                  ),
                  const SizedBox(width: 8),
                  _PickButton(
                    label: 'B',
                    selected: picks[key] == 'B',
                    onTap: () => onPick(key, 'B'),
                  ),
                ],
              ),
            ),
          ).animate().fade(duration: 200.ms, delay: (30 * i).ms).slideY(begin: 0.04, end: 0);
        }),
      ],
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: selected ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
