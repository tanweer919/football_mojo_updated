import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/predictions_repository.dart';

Future<void> showPredictSheet(
  BuildContext context, {
  required String matchId,
  required String homeName,
  required String awayName,
  int initialHome = 1,
  int initialAway = 1,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PredictSheet(
      matchId: matchId,
      homeName: homeName,
      awayName: awayName,
      initialHome: initialHome,
      initialAway: initialAway,
    ),
  );
}

class _PredictSheet extends ConsumerStatefulWidget {
  const _PredictSheet({
    required this.matchId,
    required this.homeName,
    required this.awayName,
    required this.initialHome,
    required this.initialAway,
  });
  final String matchId;
  final String homeName;
  final String awayName;
  final int initialHome;
  final int initialAway;
  @override
  ConsumerState<_PredictSheet> createState() => _PredictSheetState();
}

class _PredictSheetState extends ConsumerState<_PredictSheet> {
  late int _home = widget.initialHome;
  late int _away = widget.initialAway;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Predict the score', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _Stepper(label: widget.homeName, value: _home, onChanged: (v) => setState(() => _home = v))),
                const SizedBox(width: 8),
                Text('—', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Expanded(child: _Stepper(label: widget.awayName, value: _away, onChanged: (v) => setState(() => _away = v))),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await ref
                            .read(predictionsRepositoryProvider)
                            .submit(widget.matchId, _home, _away);
                        if (!mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Prediction saved')),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => _saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                      }
                    },
              child: Text(_saving ? 'Saving…' : 'Lock in prediction'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: value > 0 ? () => onChanged(value - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Text(
                  '$value',
                  key: ValueKey(value),
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w900, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
              IconButton(
                onPressed: value < 12 ? () => onChanged(value + 1) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
