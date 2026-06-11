import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportsmojo/features/matches/presentation/widgets/match_share_card.dart';
import 'package:sportsmojo/features/scores/data/models/match_dto.dart';

/// Proves the share graphic actually rasterises off-screen. If MatchShareCard
/// has a layout fault, toImage() throws here instead of silently returning a
/// null path in production (which is why "no graphic" shows up).
void main() {
  Future<void> capture(WidgetTester tester, MatchDto match) async {
    await tester.binding.setSurfaceSize(MatchShareCard.logicalSize);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: SizedBox.fromSize(
            size: MatchShareCard.logicalSize,
            child: MatchShareCard(match: match),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    expect(image.width, MatchShareCard.logicalSize.width.toInt());
    image.dispose();
  }

  MatchDto base(MatchStatus status, {int home = 0, int away = 0}) => MatchDto(
        id: '1',
        competitionId: 'WC2026',
        homeTeam: const TeamDto(id: 'h', name: 'Mexico', shortName: 'MEX'),
        awayTeam: const TeamDto(id: 'a', name: 'South Africa', shortName: 'SOU'),
        kickoffAt: DateTime(2026, 6, 12, 20, 0),
        status: status,
        homeScore: home,
        awayScore: away,
        stage: 'Group A',
        venue: 'Estadio Azteca, Mexico City',
      );

  testWidgets('upcoming captures', (t) => capture(t, base(MatchStatus.SCHEDULED)));
  testWidgets('live captures',
      (t) => capture(t, base(MatchStatus.LIVE, home: 1, away: 0)));
  testWidgets('finished captures',
      (t) => capture(t, base(MatchStatus.FINISHED, home: 2, away: 1)));
}
