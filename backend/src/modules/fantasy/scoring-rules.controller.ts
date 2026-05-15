import { Controller, Get, Param } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import {
  ALL_AROUND_CAP, ALL_AROUND_WEIGHTS, APPEARANCE_POINTS,
  CAPTAIN_MULTIPLIER, DECISIVE, POSITION_RULES, SCORE_CEILING, SCORE_FLOOR, SQUAD,
} from './fantasy.constants';

/**
 * Public transparency endpoint. Clients render the entire scoring system from
 * this single payload — no copy-paste constants in the mobile app.
 */
@Controller({ path: 'scoring', version: '1' })
export class ScoringRulesController {
  constructor(private readonly prisma: PrismaService) {}

  @Get('rules')
  rules() {
    return {
      squad: SQUAD,
      total: { floor: SCORE_FLOOR, ceiling: SCORE_CEILING, captainMultiplier: CAPTAIN_MULTIPLIER },
      buckets: [
        {
          id: 'appearance',
          name: 'Appearance',
          description: 'Points awarded for playing.',
          items: [
            { key: 'played',   label: 'Played 1+ minute',   value: APPEARANCE_POINTS.played },
            { key: 'played60', label: 'Played 60+ minutes', value: APPEARANCE_POINTS.played60 },
          ],
        },
        {
          id: 'allAround',
          name: 'All-Around',
          description: 'Volume of game actions — passing, duels, fouls. Position-weighted.',
          cap: ALL_AROUND_CAP,
          weights: ALL_AROUND_WEIGHTS,
        },
        {
          id: 'decisive',
          name: 'Decisive',
          description: 'Game-changing moments: goals, assists, clean sheets, cards.',
          cap: DECISIVE.cap, floor: DECISIVE.floor,
          weights: {
            goal: DECISIVE.goal,
            penaltyGoal: DECISIVE.penaltyGoal,
            assist: DECISIVE.assist,
            cleanSheet: DECISIVE.cleanSheet,
            twoConceded: DECISIVE.twoConceded,
            ownGoal: DECISIVE.ownGoal,
            yellowCard: DECISIVE.yellowCard,
            redCard: DECISIVE.redCard,
            penaltyMiss: DECISIVE.penaltyMiss,
            penaltyWon: DECISIVE.penaltyWon,
            penaltyCommit: DECISIVE.penaltyCommit,
          },
        },
        {
          id: 'position',
          name: 'Position',
          description: 'Position-specific actions. GKs save shots; defenders block them; midfielders create chances; forwards take them.',
          cap: POSITION_RULES.cap,
          weights: {
            GK: POSITION_RULES.GK, DEF: POSITION_RULES.DEF,
            MID: POSITION_RULES.MID, FWD: POSITION_RULES.FWD,
          },
        },
      ],
    };
  }

  /** Per-player breakdown for a specific gameweek. Used by the "My points" screen. */
  @Get('breakdown/:gameweekId/:playerId')
  async breakdown(@Param('gameweekId') gameweekId: string, @Param('playerId') playerId: string) {
    return this.prisma.playerGameweekScore.findUnique({
      where: { playerId_gameweekId: { playerId, gameweekId } },
      include: { player: { include: { team: true } } },
    });
  }

  /** Full breakdown for every player in a lineup. Used by the "My team scored" screen. */
  @Get('lineup/:gameweekId/:userId')
  async lineupBreakdown(@Param('gameweekId') gameweekId: string, @Param('userId') userId: string) {
    const lineup = await this.prisma.fantasyLineup.findUnique({
      where: { userId_gameweekId: { userId, gameweekId } },
    });
    if (!lineup) return null;
    const picks = lineup.picks as Array<{ playerId: string; position: string; isCaptain?: boolean }>;
    const scores = await this.prisma.playerGameweekScore.findMany({
      where: { gameweekId, playerId: { in: picks.map((p) => p.playerId) } },
      include: { player: { include: { team: true } } },
    });
    const scoreByPlayer = new Map(scores.map((s) => [s.playerId, s]));
    return {
      total: lineup.totalPoints,
      rank: lineup.rank,
      captainId: lineup.captainId,
      players: picks.map((p) => ({
        ...p,
        score: scoreByPlayer.get(p.playerId) ?? null,
      })),
    };
  }
}
