import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../fantasy/presentation/providers/fantasy_providers.dart';
import '../../../profile/data/profile_repository.dart';
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

enum _Mode { link, direct }

class _ChallengeComposerState extends ConsumerState<_ChallengeComposer> {
  final _opponentCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  _Mode _mode = _Mode.link;
  String? _selectedGameweekId;
  bool _busy = false;
  String? _error;
  // Typeahead state for direct-mode @tag / name search.
  Timer? _searchDebounce;
  List<UserSearchHit> _searchResults = const [];
  bool _searching = false;
  UserSearchHit? _selectedOpponent;

  @override
  void initState() {
    super.initState();
    _opponentCtrl.addListener(_onOpponentChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _opponentCtrl.removeListener(_onOpponentChanged);
    _opponentCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _onOpponentChanged() {
    // Clear the locked-in choice when the user keeps typing — otherwise
    // the displayed selection drifts away from the text in the field.
    if (_selectedOpponent != null &&
        _opponentCtrl.text.trim() !=
            (_selectedOpponent!.userTag != null
                ? '@${_selectedOpponent!.userTag}'
                : _selectedOpponent!.id)) {
      _selectedOpponent = null;
    }
    _searchDebounce?.cancel();
    final raw = _opponentCtrl.text.trim();
    // Strip a leading @ before searching — server expects bare query.
    final q = raw.startsWith('@') ? raw.substring(1) : raw;
    if (q.length < 2) {
      setState(() => _searchResults = const []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() => _searching = true);
      try {
        final hits = await ref.read(profileRepositoryProvider).search(q);
        if (!mounted) return;
        setState(() {
          _searchResults = hits;
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _searchResults = const [];
          _searching = false;
        });
      }
    });
  }

  void _pickOpponent(UserSearchHit hit) {
    setState(() {
      _selectedOpponent = hit;
      _opponentCtrl.text = hit.userTag != null ? '@${hit.userTag}' : hit.id;
      _opponentCtrl.selection =
          TextSelection.collapsed(offset: _opponentCtrl.text.length);
      _searchResults = const [];
    });
  }

  Future<void> _send() async {
    if (_selectedGameweekId == null) {
      setState(() => _error = 'Pick a gameweek');
      return;
    }
    if (_mode == _Mode.direct && _opponentCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter a user ID or @tag');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await ref.read(h2hRepositoryProvider).propose(
            opponentId: _mode == _Mode.direct ? _opponentCtrl.text.trim() : null,
            gameweekId: _selectedGameweekId!,
            message: _messageCtrl.text.trim().isEmpty
                ? null
                : _messageCtrl.text.trim(),
          );
      ref.invalidate(h2hListProvider);
      if (!mounted) return;
      Navigator.of(context).pop(true);

      if (challenge.inviteToken != null) {
        // Open-invite mode: surface a share dialog immediately so the user
        // can pass the link to a friend in one tap.
        final link = 'https://pitch.app/h2h/i/${challenge.inviteToken}';
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Invite ready'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share this link — first friend to open it accepts.'),
                const SizedBox(height: 12),
                SelectableText(
                  link,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: link));
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Link copied')),
                  );
                },
                child: const Text('Copy'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Share'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  SharePlus.instance.share(
                    ShareParams(
                      text: 'Challenge me on PITCH: $link',
                      subject: 'PITCH 1v1 invite',
                    ),
                  );
                },
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Challenge sent')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tournament = ref.watch(tournamentProvider(kGlobalCupSlug));
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20,
            MediaQuery.viewInsetsOf(context).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Challenge a friend',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            SegmentedButton<_Mode>(
              segments: const [
                ButtonSegment(
                    value: _Mode.link,
                    label: Text('Share link'),
                    icon: Icon(Icons.link)),
                ButtonSegment(
                    value: _Mode.direct,
                    label: Text('By ID / @tag'),
                    icon: Icon(Icons.alternate_email)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 12),
            if (_mode == _Mode.direct) ...[
              TextField(
                controller: _opponentCtrl,
                decoration: InputDecoration(
                  labelText: 'Opponent — @tag or display name',
                  helperText: 'Type 2+ characters to search.',
                  prefixIcon: const Icon(Icons.alternate_email, size: 18),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : _selectedOpponent != null
                          ? Icon(Icons.check_circle_rounded,
                              color: theme.colorScheme.primary, size: 20)
                          : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 240),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _searchResults.length,
                    itemBuilder: (_, i) {
                      final h = _searchResults[i];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundImage: h.photoUrl != null
                              ? CachedNetworkImageProvider(h.photoUrl!)
                              : null,
                          child: h.photoUrl == null
                              ? const Icon(Icons.person, size: 16)
                              : null,
                        ),
                        title: Text(
                          h.displayName ??
                              (h.userTag != null ? '@${h.userTag}' : 'Player'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: h.userTag != null && h.displayName != null
                            ? Text('@${h.userTag}')
                            : null,
                        onTap: () => _pickOpponent(h),
                      );
                    },
                  ),
                ),
              ],
            ]
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You\'ll get a shareable link. Whoever opens it first becomes your opponent.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            tournament.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('$e',
                  style: TextStyle(color: theme.colorScheme.error)),
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
                  items: upcoming
                      .map((g) => DropdownMenuItem(
                            value: g.id,
                            child: Text(g.name, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
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
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child:
                    Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: Icon(_mode == _Mode.link ? Icons.link : Icons.send),
              label: Text(_busy
                  ? 'Sending…'
                  : (_mode == _Mode.link
                      ? 'Create invite link'
                      : 'Send challenge')),
              onPressed: _busy ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
