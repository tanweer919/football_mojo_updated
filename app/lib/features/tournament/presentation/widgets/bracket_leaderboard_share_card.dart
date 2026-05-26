import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/share/share_card_frame.dart';
import '../../../predictions/data/predictions_repository.dart';

/// Bracket leaderboard share artifact.
///
/// Two modes:
///   - "rank in context": the user is on the leaderboard. Shows their row
///     + 2 above + 2 below, centred on their position, with their row
///     highlighted in gold.
///   - "podium": user isn't on the board (or wasn't passed). Shows top 3
///     with a classic 1-2-3 stepped layout, gold for first.
class BracketLeaderboardShareCard extends StatelessWidget {
  const BracketLeaderboardShareCard({
    super.key,
    required this.rows,
    this.myUserId,
    this.userHandle,
  });

  final List<BracketLeaderRow> rows;
  final String? myUserId;
  final String? userHandle;

  bool get _onBoard =>
      myUserId != null && rows.any((r) => r.userId == myUserId);

  /// Window of 5 rows centred on the caller. Falls back when the caller is
  /// near the top / bottom so we always show 5 (or all rows if fewer).
  List<BracketLeaderRow> _rankInContext() {
    final me = rows.indexWhere((r) => r.userId == myUserId);
    if (me < 0) return rows.take(5).toList(growable: false);
    final start = (me - 2).clamp(0, rows.length).toInt();
    final end = (start + 5).clamp(0, rows.length).toInt();
    // Push the window back up if we hit the bottom edge.
    final adjustedStart = (end - 5).clamp(0, start).toInt();
    return rows.sublist(adjustedStart, end);
  }

  @override
  Widget build(BuildContext context) {
    final isOnBoard = _onBoard;
    final myRank = isOnBoard
        ? rows.firstWhere((r) => r.userId == myUserId).rank
        : null;
    return ShareCardFrame(
      title: isOnBoard ? 'WORLD CUP BRACKET' : 'TOP 3 BRACKETS',
      subtitle: isOnBoard
          ? 'I\'m ranked #$myRank.'
          : 'The smartest takes so far.',
      userHandle: userHandle,
      child: isOnBoard
          ? _ContextList(rows: _rankInContext(), myUserId: myUserId)
          : _Podium(rows: rows.take(3).toList(growable: false)),
    );
  }
}

class _ContextList extends StatelessWidget {
  const _ContextList({required this.rows, required this.myUserId});
  final List<BracketLeaderRow> rows;
  final String? myUserId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          _Row(row: rows[i], isMe: rows[i].userId == myUserId),
          if (i < rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.isMe});
  final BracketLeaderRow row;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final bg = isMe
        ? const Color(0x33D9B65A)
        : const Color(0xFF1E1A14);
    final border = isMe
        ? const Color(0xFFEBD9A8)
        : const Color(0x33D9B65A);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: isMe ? 2 : 1),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              '#${row.rank}',
              style: TextStyle(
                color: isMe ? const Color(0xFFEBD9A8) : Colors.white60,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          CircleAvatar(
            radius: 16,
            backgroundImage: row.photoUrl != null
                ? CachedNetworkImageProvider(row.photoUrl!)
                : null,
            child: row.photoUrl == null
                ? const Icon(Icons.person, size: 16)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.displayName ?? 'Manager',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            '${row.total} pts',
            style: TextStyle(
              color: isMe ? const Color(0xFFEBD9A8) : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.rows});
  final List<BracketLeaderRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'No brackets scored yet.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    // Layout the podium as 2-1-3 (silver, gold, bronze) for a classic look.
    final first  = rows[0];
    final second = rows.length > 1 ? rows[1] : null;
    final third  = rows.length > 2 ? rows[2] : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: second == null ? const SizedBox.shrink() : _Step(row: second, height: 120, accent: const Color(0xFFC0C0C0), tier: 2)),
          Expanded(child: _Step(row: first, height: 170, accent: const Color(0xFFEBD9A8), tier: 1)),
          Expanded(child: third == null ? const SizedBox.shrink() : _Step(row: third, height: 90, accent: const Color(0xFFB87333), tier: 3)),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.row,
    required this.height,
    required this.accent,
    required this.tier,
  });
  final BracketLeaderRow row;
  final double height;
  final Color accent;
  final int tier;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundImage: row.photoUrl != null
              ? CachedNetworkImageProvider(row.photoUrl!)
              : null,
          child: row.photoUrl == null
              ? const Icon(Icons.person, size: 22)
              : null,
        ),
        const SizedBox(height: 6),
        Text(
          row.displayName ?? 'Manager',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '${row.total} pts',
          style: TextStyle(
            color: accent,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withValues(alpha: 0.5),
                accent.withValues(alpha: 0.15),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: accent.withValues(alpha: 0.6)),
          ),
          child: Center(
            child: Text(
              '$tier',
              style: TextStyle(
                color: accent,
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
