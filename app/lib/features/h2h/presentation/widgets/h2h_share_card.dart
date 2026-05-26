import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/share/share_card_frame.dart';
import '../../data/h2h_repository.dart';

class H2HShareCard extends StatelessWidget {
  const H2HShareCard({
    super.key,
    required this.challenge,
    this.userHandle,
  });
  final H2HChallenge challenge;
  final String? userHandle;

  String get _statusLabel {
    switch (challenge.status) {
      case H2HStatus.PENDING:
        return 'CHALLENGE ISSUED';
      case H2HStatus.ACCEPTED:
        return 'LOCKED IN';
      case H2HStatus.LOCKED:
        return 'BATTLE BEGINS';
      case H2HStatus.RESOLVED:
        return challenge.winnerId == null
            ? 'A DRAW'
            : (challenge.winnerId == challenge.challenger.id
                ? '${challenge.challenger.displayName ?? "Challenger"} WINS'
                : '${challenge.opponent?.displayName ?? "Opponent"} WINS');
      case H2HStatus.DECLINED:
      case H2HStatus.CANCELLED:
        return 'CHALLENGE CLOSED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ShareCardFrame(
      title: _statusLabel,
      subtitle: challenge.gameweekName,
      userHandle: userHandle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _Side(
              user: challenge.challenger,
              score: challenge.challengerScore,
              winner: challenge.winnerId == challenge.challenger.id,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'VS',
              style: TextStyle(
                color: Color(0xFFB78A2E),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: challenge.opponent == null
                ? const Center(
                    child: Text(
                      'Anyone\nwith the link',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  )
                : _Side(
                    user: challenge.opponent!,
                    score: challenge.opponentScore,
                    winner: challenge.winnerId == challenge.opponent!.id,
                  ),
          ),
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.user,
    required this.score,
    required this.winner,
  });
  final H2HUserSummary user;
  final double score;
  final bool winner;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: winner ? const Color(0xFFEBD9A8) : Colors.white24,
              width: winner ? 3 : 1,
            ),
            boxShadow: winner
                ? [
                    BoxShadow(
                      color: const Color(0xFFEBD9A8).withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            radius: 36,
            backgroundImage: user.photoUrl != null
                ? CachedNetworkImageProvider(user.photoUrl!)
                : null,
            child: user.photoUrl == null
                ? const Icon(Icons.person, size: 30)
                : null,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          user.displayName ?? 'Player',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          score.toStringAsFixed(1),
          style: TextStyle(
            color: winner ? const Color(0xFFEBD9A8) : Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
