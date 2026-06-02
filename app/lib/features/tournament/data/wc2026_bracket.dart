// FIFA World Cup 2026 bracket structure.
//
// 48 teams → 12 groups of 4 → top 2 + 8 best thirds = 32 → R32 → R16 → QF →
// SF → Final (+ bronze). Each knockout slot is defined by a `_SlotSource`
// rule that references either a group standing or an earlier match winner.
//
// Scoring + UI both consume this config so the matchups stay consistent
// across the bracket screen and the backend scorer.

/// One side of a knockout match. Three flavours:
///   - GroupSlot(letter, position)        → "Group A runner-up"  (position 1..4)
///   - MatchWinner(matchNumber)           → "Winner of Match 73"
///   - BestThird(eligibleGroups)          → "Third place from groups A/B/C/D/F"
sealed class BracketSlotSource {
  const BracketSlotSource();
  String get label;
}

class GroupSlot extends BracketSlotSource {
  const GroupSlot(this.groupLetter, this.position);
  final String groupLetter;
  final int position; // 1, 2, 3, or 4

  @override
  String get label {
    final suffix = switch (position) {
      1 => 'winner',
      2 => 'runner-up',
      3 => '3rd place',
      4 => '4th place',
      _ => 'position $position',
    };
    return 'Group $groupLetter $suffix';
  }
}

class MatchWinner extends BracketSlotSource {
  const MatchWinner(this.matchNumber);
  final int matchNumber;
  @override
  String get label => 'Winner of M$matchNumber';
}

/// The LOSER of an earlier match — used for the bronze final, which pits
/// the two semi-final losers. Resolved by the screen as "the side of
/// match N that the user did NOT pick as winner".
class MatchLoser extends BracketSlotSource {
  const MatchLoser(this.matchNumber);
  final int matchNumber;
  @override
  String get label => 'Loser of M$matchNumber';
}

class BestThird extends BracketSlotSource {
  const BestThird(this.eligibleGroups);
  /// Group letters the FIFA table allows for this slot — the actual third
  /// gets assigned once the 8 qualifying thirds are determined. For the
  /// predictor we surface this as "Best 3rd" and let the user pick the
  /// winner side without knowing the exact team.
  final List<String> eligibleGroups;
  @override
  String get label => '3rd place ${eligibleGroups.join('/')}';
}

/// One knockout match — two slot rules + match number + the round it belongs
/// to. Rendered as a head-to-head card; user taps one side to mark winner.
class BracketMatch {
  const BracketMatch({
    required this.number,
    required this.round,
    required this.left,
    required this.right,
  });
  final int number;
  final BracketRound round;
  final BracketSlotSource left;
  final BracketSlotSource right;
}

enum BracketRound { r32, r16, qf, sf, bronze, finalRound }

extension BracketRoundLabel on BracketRound {
  String get title => switch (this) {
        BracketRound.r32       => 'Round of 32',
        BracketRound.r16       => 'Round of 16',
        BracketRound.qf        => 'Quarter-finals',
        BracketRound.sf        => 'Semi-finals',
        BracketRound.bronze    => 'Bronze final',
        BracketRound.finalRound => 'Final',
      };
  /// Points awarded per correct winner in this round.
  int get points => switch (this) {
        BracketRound.r32        => 10,
        BracketRound.r16        => 25,
        BracketRound.qf         => 50,
        BracketRound.sf         => 100,
        BracketRound.bronze     => 75,
        BracketRound.finalRound => 500,
      };
}

/// All 12 group letters in display order.
const wcGroupLetters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L'];

/// FIFA WC2026 knockout-stage wiring, as per the published schedule.
/// Source: FIFA.com fixture list (matches 73–104).
const wc2026Matches = <BracketMatch>[
  // ── ROUND OF 32 ─────────────────────────────────────────────────────────
  BracketMatch(
    number: 73, round: BracketRound.r32,
    left:  GroupSlot('A', 2),
    right: GroupSlot('B', 2),
  ),
  BracketMatch(
    number: 74, round: BracketRound.r32,
    left:  GroupSlot('E', 1),
    right: BestThird(['A', 'B', 'C', 'D', 'F']),
  ),
  BracketMatch(
    number: 75, round: BracketRound.r32,
    left:  GroupSlot('F', 1),
    right: GroupSlot('C', 2),
  ),
  BracketMatch(
    number: 76, round: BracketRound.r32,
    left:  GroupSlot('C', 1),
    right: GroupSlot('F', 2),
  ),
  BracketMatch(
    number: 77, round: BracketRound.r32,
    left:  GroupSlot('I', 1),
    right: BestThird(['C', 'D', 'F', 'G', 'H']),
  ),
  BracketMatch(
    number: 78, round: BracketRound.r32,
    left:  GroupSlot('E', 2),
    right: GroupSlot('I', 2),
  ),
  BracketMatch(
    number: 79, round: BracketRound.r32,
    left:  GroupSlot('A', 1),
    right: BestThird(['C', 'E', 'F', 'H', 'I']),
  ),
  BracketMatch(
    number: 80, round: BracketRound.r32,
    left:  GroupSlot('L', 1),
    right: BestThird(['E', 'H', 'I', 'J', 'K']),
  ),
  BracketMatch(
    number: 81, round: BracketRound.r32,
    left:  GroupSlot('D', 1),
    right: BestThird(['B', 'E', 'F', 'I', 'J']),
  ),
  BracketMatch(
    number: 82, round: BracketRound.r32,
    left:  GroupSlot('G', 1),
    right: BestThird(['A', 'E', 'H', 'I', 'J']),
  ),
  BracketMatch(
    number: 83, round: BracketRound.r32,
    left:  GroupSlot('K', 2),
    right: GroupSlot('L', 2),
  ),
  BracketMatch(
    number: 84, round: BracketRound.r32,
    left:  GroupSlot('H', 1),
    right: GroupSlot('J', 2),
  ),
  BracketMatch(
    number: 85, round: BracketRound.r32,
    left:  GroupSlot('B', 1),
    right: BestThird(['E', 'F', 'G', 'I', 'J']),
  ),
  BracketMatch(
    number: 86, round: BracketRound.r32,
    left:  GroupSlot('J', 1),
    right: GroupSlot('H', 2),
  ),
  BracketMatch(
    number: 87, round: BracketRound.r32,
    left:  GroupSlot('K', 1),
    right: BestThird(['D', 'E', 'I', 'J', 'L']),
  ),
  BracketMatch(
    number: 88, round: BracketRound.r32,
    left:  GroupSlot('D', 2),
    right: GroupSlot('G', 2),
  ),

  // ── ROUND OF 16 ─────────────────────────────────────────────────────────
  BracketMatch(number: 89, round: BracketRound.r16, left: MatchWinner(74), right: MatchWinner(77)),
  BracketMatch(number: 90, round: BracketRound.r16, left: MatchWinner(73), right: MatchWinner(75)),
  BracketMatch(number: 91, round: BracketRound.r16, left: MatchWinner(76), right: MatchWinner(78)),
  BracketMatch(number: 92, round: BracketRound.r16, left: MatchWinner(79), right: MatchWinner(80)),
  BracketMatch(number: 93, round: BracketRound.r16, left: MatchWinner(83), right: MatchWinner(84)),
  BracketMatch(number: 94, round: BracketRound.r16, left: MatchWinner(81), right: MatchWinner(82)),
  BracketMatch(number: 95, round: BracketRound.r16, left: MatchWinner(86), right: MatchWinner(88)),
  BracketMatch(number: 96, round: BracketRound.r16, left: MatchWinner(85), right: MatchWinner(87)),

  // ── QUARTER-FINALS ──────────────────────────────────────────────────────
  BracketMatch(number: 97,  round: BracketRound.qf, left: MatchWinner(89), right: MatchWinner(90)),
  BracketMatch(number: 98,  round: BracketRound.qf, left: MatchWinner(93), right: MatchWinner(94)),
  BracketMatch(number: 99,  round: BracketRound.qf, left: MatchWinner(91), right: MatchWinner(92)),
  BracketMatch(number: 100, round: BracketRound.qf, left: MatchWinner(95), right: MatchWinner(96)),

  // ── SEMI-FINALS ─────────────────────────────────────────────────────────
  BracketMatch(number: 101, round: BracketRound.sf, left: MatchWinner(97), right: MatchWinner(98)),
  BracketMatch(number: 102, round: BracketRound.sf, left: MatchWinner(99), right: MatchWinner(100)),

  // ── BRONZE + FINAL ──────────────────────────────────────────────────────
  // Bronze pits the two semi-final losers.
  BracketMatch(
    number: 103, round: BracketRound.bronze,
    left:  MatchLoser(101),
    right: MatchLoser(102),
  ),
  BracketMatch(
    number: 104, round: BracketRound.finalRound,
    left:  MatchWinner(101),
    right: MatchWinner(102),
  ),
];

/// Helpful index for fast lookup by match number.
final wc2026MatchesByNumber = <int, BracketMatch>{
  for (final m in wc2026Matches) m.number: m,
};

const wc2026ChampionMatchNumber = 104;

/// Total picks across the new shape:
///   - 48 group positions (12 × 4)
///   - 8 best-third picks
///   - 32 match winners (R32) — wait, R32 = 16. Let me recount.
///     R32 (16) + R16 (8) + QF (4) + SF (2) + Bronze (1) + Final (1) = 32
///   Total: 48 + 8 + 32 = 88
const wc2026TotalPicks = 48 + 8 + 32;
