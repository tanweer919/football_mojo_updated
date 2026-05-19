import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/auth/sign_in_sheet.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/loading_skeletons.dart';
import '../../../../core/widgets/pcard.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../album/data/models/card_models.dart' show CardRarity;
import '../../data/models/fantasy_models.dart';
import '../../data/repositories/fantasy_repository.dart';
import '../providers/fantasy_providers.dart';
import 'player_picker_sheet.dart';

/// Build XI — focused, single-screen flow:
///   - Sticky topbar (back / "Build XI · GW N" / reset)
///   - Deadline + budget cards
///   - Painted pitch with 5 slots (GK / DEF / MID / UTL / FWD)
///   - Bench row
///   - Sticky bottom action bar (auto-fill / save / captain) — anchored to
///     SafeArea so the system nav bar never overlaps it.
///
/// Auth-gated save: triggers Google sign-in inline if anonymous.
class LineupBuilderScreen extends ConsumerStatefulWidget {
  const LineupBuilderScreen({super.key, required this.slug, required this.gameweekId});
  final String slug;
  final String gameweekId;
  @override
  ConsumerState<LineupBuilderScreen> createState() => _LineupBuilderScreenState();
}

enum _Slot { gk, def, mid, utl, fwd, sub }

extension on _Slot {
  String get label => switch (this) {
        _Slot.gk => 'GK',
        _Slot.def => 'DEF',
        _Slot.mid => 'MID',
        _Slot.utl => 'UTL',
        _Slot.fwd => 'FWD',
        _Slot.sub => 'SUB',
      };
  // longLabel removed with the inline picker — the new picker computes
  // its own header label from `allowedPositions`.
  List<PlayerPosition> get allowedPositions => switch (this) {
        _Slot.gk => [PlayerPosition.GK],
        _Slot.def => [PlayerPosition.DEF],
        _Slot.mid => [PlayerPosition.MID],
        _Slot.utl => [PlayerPosition.DEF, PlayerPosition.MID, PlayerPosition.FWD],
        _Slot.fwd => [PlayerPosition.FWD],
        _Slot.sub => [PlayerPosition.GK, PlayerPosition.DEF, PlayerPosition.MID, PlayerPosition.FWD],
      };
}

class _LineupBuilderScreenState extends ConsumerState<LineupBuilderScreen> {
  bool _hydrated = false;
  Map<_Slot, String?> _picks = {for (final s in _Slot.values) s: null};
  _Slot _captain = _Slot.fwd;
  Timer? _ticker;
  Duration _untilLock = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refreshCountdown());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _refreshCountdown() {
    final gw = ref.read(currentGameweekProvider(widget.slug)).valueOrNull;
    if (gw == null) return;
    final remaining = gw.lockAt.difference(DateTime.now());
    if (mounted) setState(() => _untilLock = remaining.isNegative ? Duration.zero : remaining);
  }

  void _hydrateFrom(FantasyLineupDto lineup) {
    final next = <_Slot, String?>{for (final s in _Slot.values) s: null};
    final byPos = <PlayerPosition, List<LineupPick>>{};
    for (final p in lineup.picks) {
      byPos.putIfAbsent(p.position, () => []).add(p);
    }
    next[_Slot.gk]  = byPos[PlayerPosition.GK]?.firstOrNull?.playerId;
    next[_Slot.def] = byPos[PlayerPosition.DEF]?.firstOrNull?.playerId;
    next[_Slot.mid] = byPos[PlayerPosition.MID]?.firstOrNull?.playerId;
    next[_Slot.fwd] = byPos[PlayerPosition.FWD]?.firstOrNull?.playerId;
    final extras = lineup.picks
        .where((p) => p.playerId != next[_Slot.def] && p.playerId != next[_Slot.mid] && p.playerId != next[_Slot.fwd])
        .where((p) => p.position != PlayerPosition.GK)
        .toList();
    if (extras.isNotEmpty) next[_Slot.utl] = extras.first.playerId;
    setState(() {
      _picks = next;
      for (final entry in next.entries) {
        if (entry.value == lineup.captainId) {
          _captain = entry.key;
          break;
        }
      }
    });
  }

  double _spent(Map<String, PlayerValuationDto> byId, double cap) {
    double s = 0;
    for (final entry in _picks.entries) {
      if (entry.key == _Slot.sub) continue;
      final id = entry.value;
      if (id == null) continue;
      s += byId[id]?.price ?? 0;
    }
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final tournament = ref.watch(tournamentProvider(widget.slug));
    final players = ref.watch(selectablePlayersProvider(widget.slug));
    final mine = ref.watch(myLineupProvider((slug: widget.slug, gameweekId: widget.gameweekId)));
    final gw = ref.watch(currentGameweekProvider(widget.slug));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: tournament.when(
          loading: () => const _LoadingState(),
          error: (e, _) => _ErrorState(message: '$e'),
          data: (t) => players.when(
            loading: () => const _LoadingState(),
            error: (e, _) => _ErrorState(message: '$e'),
            data: (vals) {
              mine.whenData((lineup) {
                if (!_hydrated && lineup != null) {
                  _hydrated = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _hydrateFrom(lineup);
                  });
                }
              });

              final byId = {for (final v in vals) v.playerId: v};
              final cap = t.budget;
              final spent = _spent(byId, cap);
              final isOver = spent > cap;
              final remaining = cap - spent;
              final filled = [_Slot.gk, _Slot.def, _Slot.mid, _Slot.utl, _Slot.fwd]
                  .where((s) => _picks[s] != null).length;
              final canSave = filled == 5 && !isOver;

              return Column(
                children: [
                  _Topbar(
                    gameweekNumber: gw.valueOrNull?.number,
                    onBack: () => context.pop(),
                    onReset: () => setState(() {
                      _picks = {for (final s in _Slot.values) s: null};
                      _captain = _Slot.fwd;
                    }),
                  ),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _StatusStrip(remaining: _untilLock, spent: spent, cap: cap, isOver: isOver, filled: filled),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _Pitch(
                            picks: _picks,
                            byId: byId,
                            captain: _captain,
                            onSlotTap: (slot) => _openPicker(slot, byId, remaining),
                            onCaptainTap: (slot) => setState(() => _captain = slot),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _BenchRow(
                            sub: _picks[_Slot.sub] == null ? null : byId[_picks[_Slot.sub]],
                            onSwap: () => _openPicker(_Slot.sub, byId, remaining),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Tap a player to swap. Tap the captain badge to set captain (×2 points).',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: AppColors.muted2,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _SaveBar(
                    canSave: canSave,
                    isOver: isOver,
                    filled: filled,
                    spent: spent,
                    cap: cap,
                    onAuto: () => _autoFill(vals, byId, cap),
                    onSave: canSave ? () => _save(byId, t) : null,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _autoFill(List<PlayerValuationDto> all, Map<String, PlayerValuationDto> byId, double cap) {
    final used = _picks.values.whereType<String>().toSet();
    for (final slot in [_Slot.gk, _Slot.def, _Slot.mid, _Slot.utl, _Slot.fwd]) {
      if (_picks[slot] != null) continue;
      final allowed = slot.allowedPositions;
      final candidates = all.where((p) => allowed.contains(p.position) && !used.contains(p.playerId));
      final affordable = candidates
          .where((p) => p.price <= cap - _spent(byId, cap))
          .toList()
        ..sort((a, b) => b.recentForm.compareTo(a.recentForm));
      if (affordable.isNotEmpty) {
        setState(() => _picks[slot] = affordable.first.playerId);
        used.add(affordable.first.playerId);
      }
    }
  }

  Future<void> _openPicker(_Slot slot, Map<String, PlayerValuationDto> byId, double remaining) async {
    // Add back the price of whoever's currently in this slot — the user
    // is replacing them, so their cost frees up for the new pick.
    final budget = slot == _Slot.sub
        ? double.infinity
        : remaining + (byId[_picks[slot]]?.price ?? 0);
    final picked = await showPlayerPicker(
      context,
      tournamentSlug: widget.slug,
      allowedPositions: slot.allowedPositions.toSet(),
      excludePlayerIds: _picks.values.whereType<String>().toSet()..remove(_picks[slot] ?? ''),
      remainingBudget: budget,
    );
    if (picked != null) setState(() => _picks[slot] = picked);
  }

  Future<void> _save(Map<String, PlayerValuationDto> byId, FantasyTournamentDto t) async {
    final picks = <LineupPick>[];
    for (final slot in [_Slot.gk, _Slot.def, _Slot.mid, _Slot.utl, _Slot.fwd]) {
      final id = _picks[slot];
      if (id == null) continue;
      final v = byId[id]!;
      picks.add(LineupPick(
        playerId: id,
        position: v.position,
        isCaptain: slot == _captain,
      ));
    }
    final captainId = _picks[_captain];
    if (captainId == null) return;

    final existing = ref.read(authRepositoryProvider).currentUser;
    final user = (existing != null && !existing.isAnonymous)
        ? existing
        : await quickSignIn(context, ref);
    if (user == null) return;
    if (!mounted) return;

    try {
      await ref.read(fantasyRepositoryProvider).submitLineup(
            slug: widget.slug,
            gameweekId: widget.gameweekId,
            picks: picks,
            captainId: captainId,
          );
      if (!mounted) return;
      // Without these invalidations the user returns to the fantasy home
      // and still sees the cached "no lineup yet" — the save succeeded but
      // the UI doesn't reflect it. Same for the leaderboard, which now
      // includes their row.
      final key = (slug: widget.slug, gameweekId: widget.gameweekId);
      ref.invalidate(myLineupProvider(key));
      ref.invalidate(leaderboardProvider(key));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lineup saved · GW ready')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      // Surface the backend's actual error code (e.g. "over_budget: 105/100")
      // for long enough to read — the previous 4-second default disappeared
      // before the user could parse it.
      final msg = _formatSaveError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 6),
          backgroundColor: AppColors.surface3,
        ),
      );
    }
  }

  /// Map the backend's machine-readable error codes (`over_budget`,
  /// `bad_gk_count`, `gameweek_locked`, etc.) to short human strings.
  /// Falls back to the raw error so we never hide a useful signal.
  String _formatSaveError(Object e) {
    final raw = e.toString();
    if (raw.contains('over_budget')) {
      return 'Over budget — drop a premium pick to fit your XI.';
    }
    if (raw.contains('gameweek_locked')) {
      return 'Gameweek deadline has passed — picks are locked.';
    }
    if (raw.contains('bad_gk_count')) return 'Pick exactly 1 goalkeeper.';
    if (raw.contains('need_at_least_1_def')) return 'Need at least 1 defender.';
    if (raw.contains('need_at_least_1_mid')) return 'Need at least 1 midfielder.';
    if (raw.contains('need_at_least_1_fwd')) return 'Need at least 1 forward.';
    if (raw.contains('captain_not_in_squad')) return 'Captain must be one of your 5 picks.';
    if (raw.contains('duplicate_player')) return 'Each player can only appear once.';
    if (raw.contains('position_mismatch')) return 'A pick is in the wrong slot — rebuild and retry.';
    if (raw.contains('squad_must_have')) return 'Pick exactly 5 players.';
    return 'Could not save: $e';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ─── TOPBAR ────────────────────────────────────────────────────────────────

class _Topbar extends StatelessWidget {
  const _Topbar({required this.gameweekNumber, required this.onBack, required this.onReset});
  final int? gameweekNumber;
  final VoidCallback onBack;
  final VoidCallback onReset;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          CircleIconButton(icon: Icons.chevron_left, onPressed: onBack),
          Expanded(
            child: Center(
              child: Eyebrow(
                gameweekNumber == null ? 'Build XI' : 'Build XI · GW $gameweekNumber',
                gold: true,
                size: 11,
              ),
            ),
          ),
          CircleIconButton(icon: Icons.refresh, onPressed: onReset),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 60, 16, 16),
      child: Column(children: [SkeletonBlock(height: 80), SizedBox(height: 16), SkeletonBlock(height: 360, radius: 16)]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
        child: Text('$message', style: const TextStyle(color: AppColors.live)),
      );
}

// ─── STATUS STRIP (deadline + budget combined) ─────────────────────────────

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.remaining,
    required this.spent,
    required this.cap,
    required this.isOver,
    required this.filled,
  });
  final Duration remaining;
  final double spent;
  final double cap;
  final bool isOver;
  final int filled;

  @override
  Widget build(BuildContext context) {
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    final clockText = d > 0
        ? '${d}d ${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m'
        : '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    final pct = (spent / cap).clamp(0.0, 1.5);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.r4),
        border: Border.all(color: AppColors.goldHairline),
        gradient: const LinearGradient(
          colors: [Color(0xFF1F1814), Color(0xFF110C09)],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          // Top row — left: deadline; right: filled count.
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 14, color: AppColors.muted),
              const SizedBox(width: 6),
              const Eyebrow('Locks in', size: 10),
              const SizedBox(width: 8),
              Text(
                clockText,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.fg,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: filled == 5 ? AppColors.gold.withValues(alpha: 0.15) : AppColors.surface3,
                  border: Border.all(color: filled == 5 ? AppColors.goldHairline : AppColors.borderSoft),
                ),
                child: Text(
                  '$filled/5',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontFamilyFallback: const ['SF Mono', 'Menlo', 'monospace'],
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: filled == 5 ? AppColors.gold : AppColors.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Budget bar.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ShaderMask(
                shaderCallback: (r) => LinearGradient(
                  colors: isOver
                      ? const [Color(0xFFE26B5A), Color(0xFFB73828)]
                      : const [AppColors.goldSoft, AppColors.goldDeep],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ).createShader(r),
                child: Text(
                  spent.toStringAsFixed(0),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.12,
                    color: Colors.white,
                    height: 1.0,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Text(
                  '/ ${cap.toInt()} pts',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.muted,
                  ),
                ),
              ),
              const Spacer(),
              Eyebrow(
                isOver ? 'Over budget' : 'Remaining',
                color: isOver ? AppColors.live : AppColors.muted,
                size: 9,
              ),
              const SizedBox(width: 6),
              Text(
                isOver
                    ? '−${(spent - cap).toStringAsFixed(0)}'
                    : (cap - spent).toStringAsFixed(0),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isOver ? AppColors.live : AppColors.pitch,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Stack(
              children: [
                Container(height: 5, color: AppColors.surface3),
                FractionallySizedBox(
                  widthFactor: pct.clamp(0.0, 1.0),
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isOver
                            ? const [Color(0xFFE26B5A), Color(0xFFB73828)]
                            : const [AppColors.goldDeep, AppColors.gold, AppColors.goldSoft],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PITCH ─────────────────────────────────────────────────────────────────

class _Pitch extends StatelessWidget {
  const _Pitch({
    required this.picks,
    required this.byId,
    required this.captain,
    required this.onSlotTap,
    required this.onCaptainTap,
  });
  final Map<_Slot, String?> picks;
  final Map<String, PlayerValuationDto> byId;
  final _Slot captain;
  final ValueChanged<_Slot> onSlotTap;
  final ValueChanged<_Slot> onCaptainTap;
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.66,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _PitchPainter(),
          child: LayoutBuilder(
            builder: (_, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              return Stack(
                children: [
                  _slot(_Slot.fwd, x: 0.50, y: 0.18, w: w, h: h),
                  _slot(_Slot.mid, x: 0.32, y: 0.41, w: w, h: h),
                  _slot(_Slot.utl, x: 0.68, y: 0.41, w: w, h: h),
                  _slot(_Slot.def, x: 0.50, y: 0.65, w: w, h: h),
                  _slot(_Slot.gk,  x: 0.50, y: 0.87, w: w, h: h),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _slot(_Slot slot, {required double x, required double y, required double w, required double h}) {
    const chipW = 76.0;
    final id = picks[slot];
    final p = id == null ? null : byId[id];
    return Positioned(
      left: x * w - chipW / 2,
      top: y * h - chipW / 2,
      width: chipW,
      child: _Chip(
        slot: slot,
        player: p,
        captain: captain == slot && p != null,
        onTap: () => onSlotTap(slot),
        onCaptainTap: () {
          if (p != null) onCaptainTap(slot);
        },
      ),
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = const Color(0xFF1B6437);
    canvas.drawRect(Offset.zero & size, base);
    final stripe = Paint()..color = const Color(0xFF1F7541);
    final bandH = size.height / 8;
    for (int i = 0; i < 8; i += 2) {
      canvas.drawRect(Rect.fromLTWH(0, i * bandH, size.width, bandH), stripe);
    }
    canvas.drawCircle(
      size.center(Offset.zero),
      size.width * 0.6,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0x665EAA73),
          const Color(0x00000000),
        ]).createShader(Rect.fromCircle(center: size.center(Offset.zero), radius: size.width * 0.6)),
    );
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final frame = Rect.fromLTWH(8, 8, size.width - 16, size.height - 16);
    canvas.drawRRect(RRect.fromRectAndRadius(frame, const Radius.circular(4)), line);
    canvas.drawLine(Offset(8, size.height / 2), Offset(size.width - 8, size.height / 2), line);
    canvas.drawCircle(size.center(Offset.zero), 39, line);
    canvas.drawCircle(size.center(Offset.zero), 2, Paint()..color = Colors.white.withValues(alpha: 0.5));
    final boxW = size.width * 0.52, boxH = size.height * 0.12;
    final boxX = (size.width - boxW) / 2;
    canvas.drawRect(Rect.fromLTWH(boxX, 8, boxW, boxH), line);
    canvas.drawRect(Rect.fromLTWH(boxX, size.height - 8 - boxH, boxW, boxH), line);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.slot,
    required this.player,
    required this.captain,
    required this.onTap,
    required this.onCaptainTap,
  });
  final _Slot slot;
  final PlayerValuationDto? player;
  final bool captain;
  final VoidCallback onTap;
  final VoidCallback onCaptainTap;
  @override
  Widget build(BuildContext context) {
    final filled = player != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            if (filled)
              MiniPCard(
                rarity: _rarityFromPrice(player!.price),
                photoUrl: player!.player.photoUrl,
                lastName: player!.player.name.split(' ').last,
                position: player!.position.name,
                country: null,
                clubCrestUrl: player!.player.team.crestUrl,
                onTap: onTap,
                height: 104,
                glow: captain,
                heroTag: 'lineup-${slot.name}-${player!.playerId}',
              )
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Container(
                  width: 76,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.goldHairline, width: 1.5),
                    color: const Color(0x8C261F18),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 12, offset: const Offset(0, 6)),
                    ],
                  ),
                  child: _emptyContent(),
                ),
              ),
            if (filled)
              Positioned(
                top: -6, right: -6,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCaptainTap,
                  child: Container(
                    width: 24, height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: captain
                          ? const LinearGradient(
                              colors: [AppColors.goldSoft, AppColors.goldDeep],
                              begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            )
                          : null,
                      color: captain ? null : const Color(0xFF1F1812),
                      border: Border.all(color: AppColors.bgDeep, width: 2),
                      boxShadow: captain ? [BoxShadow(color: AppColors.goldGlow, blurRadius: 12)] : null,
                    ),
                    child: Center(
                      child: Text(
                        'C',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: captain ? const Color(0xFF1E1810) : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          filled ? slot.label : '+ ${slot.label}',
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontFamilyFallback: ['SF Mono', 'Menlo', 'monospace'],
            fontSize: 8,
            fontWeight: FontWeight.w700,
            color: AppColors.gold,
            letterSpacing: 1.44,
          ),
        ),
      ],
    );
  }

  Widget _emptyContent() => const Center(
        child: Text('+', style: TextStyle(fontFamily: 'Inter', fontSize: 28, fontWeight: FontWeight.w300, color: AppColors.gold, height: 1.0)),
      );

  /// Map a player valuation price to a card rarity so the pitch tile inherits
  /// a visual tier. The bands are deliberately wide — we want consistent
  /// "feel" across leagues with different price ranges, not pixel-perfect
  /// rarity boundaries. Tier doesn't affect scoring; it's purely cosmetic.
  CardRarity _rarityFromPrice(double price) {
    if (price >= 130) return CardRarity.ICONIC;
    if (price >= 110) return CardRarity.LEGENDARY;
    if (price >=  90) return CardRarity.EPIC;
    if (price >=  70) return CardRarity.RARE;
    if (price >=  55) return CardRarity.UNCOMMON;
    return CardRarity.COMMON;
  }
}

// ─── BENCH ─────────────────────────────────────────────────────────────────

class _BenchRow extends StatelessWidget {
  const _BenchRow({required this.sub, required this.onSwap});
  final PlayerValuationDto? sub;
  final VoidCallback onSwap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.r4),
      onTap: onSwap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.r4),
          border: Border.all(color: AppColors.borderSoft),
          color: AppColors.surface2,
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface3,
                border: Border.all(color: AppColors.goldHairline.withValues(alpha: 0.6)),
              ),
              child: ClipOval(
                child: sub == null
                    ? const Icon(Icons.add, color: AppColors.gold, size: 20)
                    : PremiumImage(url: sub!.player.photoUrl, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Eyebrow('Bench · Sub', gold: true, size: 9),
                  const SizedBox(height: 4),
                  Text(
                    sub?.player.name ?? 'Pick a substitute (free)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Eyebrow(
                    sub == null
                        ? 'Comes on if a starter is unavailable'
                        : '${sub!.position.name} · ${sub!.player.team.shortName ?? sub!.player.team.name}',
                    size: 10,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

// ─── SAVE BAR (sticky bottom, safe-area aware) ─────────────────────────────

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.canSave,
    required this.isOver,
    required this.filled,
    required this.spent,
    required this.cap,
    required this.onAuto,
    required this.onSave,
  });
  final bool canSave;
  final bool isOver;
  final int filled;
  final double spent;
  final double cap;
  final VoidCallback onAuto;
  final VoidCallback? onSave;

  String get _label {
    if (isOver) return 'Over budget · −${(spent - cap).toStringAsFixed(0)} pts';
    if (filled < 5) return 'Pick all 5 · ${5 - filled} left';
    return 'Save lineup · ${spent.toStringAsFixed(0)} pts spent';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.bgDeep,
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          GhostButton(label: 'Auto', onPressed: onAuto, small: true, icon: Icons.auto_awesome),
          const SizedBox(width: 10),
          Expanded(child: GoldButton(label: _label, onPressed: onSave, expand: true)),
        ],
      ),
    );
  }
}
