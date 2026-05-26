/// Statistical preview from api-football /predictions. We deliberately only
/// surface the comparison + advice fields — NOT odds (gambling, not halal).
class MatchPreviewDto {
  MatchPreviewDto({
    this.winnerName,
    this.winnerComment,
    this.advice,
    required this.homePercent,
    required this.drawPercent,
    required this.awayPercent,
    required this.comparison,
  });

  factory MatchPreviewDto.fromJson(Map<String, dynamic> j) {
    final preds = (j['predictions'] as Map?)?.cast<String, dynamic>() ?? const {};
    final winner = (preds['winner'] as Map?)?.cast<String, dynamic>() ?? const {};
    final percent = (preds['percent'] as Map?)?.cast<String, dynamic>() ?? const {};
    final compRaw = (j['comparison'] as Map?)?.cast<String, dynamic>() ?? const {};
    final comp = <String, ({double home, double away})>{};
    for (final e in compRaw.entries) {
      final v = (e.value as Map?)?.cast<String, dynamic>() ?? const {};
      final h = _percentToDouble(v['home']);
      final a = _percentToDouble(v['away']);
      comp[e.key] = (home: h, away: a);
    }
    return MatchPreviewDto(
      winnerName: winner['name'] as String?,
      winnerComment: winner['comment'] as String?,
      advice: preds['advice'] as String?,
      homePercent: _percentToDouble(percent['home']),
      drawPercent: _percentToDouble(percent['draw']),
      awayPercent: _percentToDouble(percent['away']),
      comparison: comp,
    );
  }

  final String? winnerName;
  final String? winnerComment;
  final String? advice;
  final double homePercent;
  final double drawPercent;
  final double awayPercent;
  final Map<String, ({double home, double away})> comparison;
}

double _percentToDouble(dynamic v) {
  if (v == null) return 0;
  final s = v.toString().replaceAll('%', '').trim();
  return double.tryParse(s) ?? 0;
}
