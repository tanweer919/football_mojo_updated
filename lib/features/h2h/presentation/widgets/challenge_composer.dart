import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../fantasy/presentation/providers/fantasy_providers.dart';
import '../../data/h2h_repository.dart';

Future<bool?> showH2HChallengeComposer(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ChallengeComposer(),
  );
}

class _ChallengeComposer extends ConsumerStatefulWidget {
  const _ChallengeComposer();
  @override
  ConsumerState<_ChallengeComposer> createState() => _ChallengeComposerState();
}

class _ChallengeComposerState extends ConsumerState<_ChallengeComposer> {
  final _opponentCtrl = TextEditingController();
  final _messageCtrl  = TextEditingController();
  String? _selectedGameweekId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _opponentCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final opponent = _opponentCtrl.text.trim();
    if (opponent.isEmpty || _selectedGameweekId == null) {
      setState(() => _error = 'Opponent ID and gameweek are required');
      return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(h2hRepositoryProvider).propose(
        opponentId: opponent,
        gameweekId: _selectedGameweekId!,
        message: _messageCtrl.text.trim().isEmpty ? null : _messageCtrl.text.trim(),
      );
      ref.invalidate(h2hListProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Challenge sent')));
    } catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _error = '$e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tournament = ref.watch(tournamentProvider(kGlobalCupSlug));
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Challenge a friend',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: _opponentCtrl,
              decoration: InputDecoration(
                labelText: 'Opponent user ID',
                helperText: 'Ask them to copy their ID from Profile.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            tournament.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e', style: TextStyle(color: theme.colorScheme.error)),
              data: (t) {
                final upcoming = t.gameweeks
                    .where((g) => g.lockAt.isAfter(DateTime.now()))
                    .toList();
                if (upcoming.isEmpty) {
                  return Text('No upcoming gameweeks',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant));
                }
                return DropdownButtonFormField<String>(
                  initialValue: _selectedGameweekId ?? upcoming.first.id,
                  decoration: InputDecoration(
                    labelText: 'Gameweek',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: upcoming.map((g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(g.name, overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedGameweekId = v),
                );
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _messageCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Message (optional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.send),
              label: Text(_busy ? 'Sending…' : 'Send challenge'),
              onPressed: _busy ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
