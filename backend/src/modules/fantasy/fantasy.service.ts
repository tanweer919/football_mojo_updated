import { BadRequestException, ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { PlayerPosition } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { OWNED_CARD_MULTIPLIER, OWNED_CARD_RARITY_ORDER, SQUAD } from './fantasy.constants';

export interface LineupPick {
  playerId: string;
  position: PlayerPosition;
  isCaptain?: boolean;
}

@Injectable()
export class FantasyService {
  constructor(private readonly prisma: PrismaService) {}

  // ─── Tournament / gameweek discovery ──────────────────────────────────────
  async listTournaments() {
    return this.prisma.fantasyTournament.findMany({
      orderBy: { startsAt: 'desc' },
      include: { gameweeks: { orderBy: { number: 'asc' } } },
    });
  }

  async getTournament(slug: string) {
    const t = await this.prisma.fantasyTournament.findUnique({
      where: { slug },
      include: { gameweeks: { orderBy: { number: 'asc' } }, prizes: { include: { cardTemplate: true } } },
    });
    if (!t) throw new NotFoundException('tournament_not_found');
    return t;
  }

  async currentGameweek(tournamentId: string) {
    const now = new Date();
    // Earliest gameweek whose deadline is in the future, else the latest past one.
    return (await this.prisma.fantasyGameweek.findFirst({
      where: { tournamentId, lockAt: { gt: now } },
      orderBy: { number: 'asc' },
    })) ?? this.prisma.fantasyGameweek.findFirst({
      where: { tournamentId },
      orderBy: { number: 'desc' },
    });
  }

  // ─── Selectable player pool ───────────────────────────────────────────────
  /**
   * Players eligible for this tournament. Filters strictly by the
   * tournament's competition — World Cup tournaments only see players
   * whose `Team.competitionId = 'WC2026'`, NEVER club-only players the
   * ingest brought in for Big-5 / UCL form data.
   *
   * This invariant is load-bearing: `prisma/ingest-player-form.ts` with
   * IMPORT_MISSING=1 creates thousands of additional Player rows for
   * Real Madrid / PSG / Liverpool etc. None should appear in WC build-XI.
   * The filter below is the only thing standing between
   * "Vinícius Jr. as a Brazil pick" (fine — he's on team BRA) and
   * "Vinícius Jr. + a duplicate Real Madrid row" (not fine).
   *
   * The asserting post-query check is defence in depth in case a future
   * ingest accidentally re-points teamId on an existing player. Throws
   * rather than returning bad data.
   */
  async listSelectablePlayers(tournamentId: string) {
    const t = await this.prisma.fantasyTournament.findUnique({
      where: { id: tournamentId },
      select: { competitionId: true },
    });
    if (!t) throw new NotFoundException('tournament_not_found');

    const rows = await this.prisma.playerValuation.findMany({
      where: { player: { team: { competitionId: t.competitionId } } },
      include: { player: { include: { team: true } } },
      orderBy: [{ position: 'asc' }, { price: 'desc' }],
    });

    // Sanity assert — every row must actually belong to the tournament's
    // competition. If this trips, the Prisma filter regressed or the
    // Team→Competition link drifted; fail loudly.
    const leak = rows.find((r) => r.player.team.competitionId !== t.competitionId);
    if (leak) {
      throw new Error(
        `selectable_pool_leak: player ${leak.playerId} (${leak.player.name}) ` +
        `team ${leak.player.teamId} competition=${leak.player.team.competitionId} ` +
        `expected=${t.competitionId}`,
      );
    }
    return rows;
  }

  // ─── Lineup submission ────────────────────────────────────────────────────
  /**
   * Validate + upsert a user's lineup for a given gameweek.
   * Enforces: position quotas, budget, captain in squad, deadline, supply-side checks.
   */
  async submitLineup(userId: string, gameweekId: string, picks: LineupPick[], captainId: string) {
    // 5-a-side composition rules:
    //   - exactly 5 picks total
    //   - exactly 1 GK
    //   - at least 1 DEF, 1 MID, 1 FWD (the dedicated outfield slots)
    //   - the 5th pick (UTL) is a free DEF/MID/FWD — covered implicitly because
    //     1+1+1+1 = 4 plus the GK = 5 with one outfield slot left to assign.
    if (picks.length !== SQUAD.size)
      throw new BadRequestException(`squad_must_have_${SQUAD.size}_players`);

    const byPos = picks.reduce<Record<string, number>>((acc, p) => {
      acc[p.position] = (acc[p.position] ?? 0) + 1; return acc;
    }, {});

    if ((byPos['GK'] ?? 0) !== SQUAD.exactGK)
      throw new BadRequestException(`bad_gk_count: ${byPos['GK'] ?? 0} expected ${SQUAD.exactGK}`);

    for (const [pos, min] of Object.entries(SQUAD.minByPosition)) {
      if ((byPos[pos] ?? 0) < min)
        throw new BadRequestException(`need_at_least_${min}_${pos.toLowerCase()}`);
    }

    const ids = picks.map((p) => p.playerId);
    if (new Set(ids).size !== ids.length) throw new BadRequestException('duplicate_player');
    if (!ids.includes(captainId)) throw new BadRequestException('captain_not_in_squad');

    const gw = await this.prisma.fantasyGameweek.findUnique({
      where: { id: gameweekId },
      include: { tournament: true },
    });
    if (!gw) throw new NotFoundException('gameweek_not_found');
    if (gw.lockAt.getTime() <= Date.now()) throw new ForbiddenException('gameweek_locked');

    const valuations = await this.prisma.playerValuation.findMany({
      where: { playerId: { in: ids } },
    });
    if (valuations.length !== ids.length) throw new BadRequestException('unknown_player');

    // Each pick's position must match the canonical valuation position.
    const vMap = new Map(valuations.map((v) => [v.playerId, v]));
    for (const p of picks) {
      const v = vMap.get(p.playerId)!;
      if (v.position !== p.position)
        throw new BadRequestException(`position_mismatch: ${p.playerId}`);
    }

    const budgetUsed = valuations.reduce((s, v) => s + v.price, 0);
    if (budgetUsed > gw.tournament.budget)
      throw new BadRequestException(`over_budget: ${budgetUsed.toFixed(1)}/${gw.tournament.budget}`);

    return this.prisma.fantasyLineup.upsert({
      where: { userId_gameweekId: { userId, gameweekId } },
      create: {
        userId, gameweekId,
        picks: picks as unknown as object,
        captainId,
        budgetUsed,
        locked: false,
      },
      update: {
        picks: picks as unknown as object,
        captainId,
        budgetUsed,
      },
    });
  }

  async getMyLineup(userId: string, gameweekId: string) {
    return this.prisma.fantasyLineup.findUnique({
      where: { userId_gameweekId: { userId, gameweekId } },
    });
  }

  /**
   * For each player the user owns a card of, return the highest-rarity
   * card + the matching scoring multiplier. The player picker uses this
   * map to render the "+25%" badge next to ownable picks; the lineup
   * builder uses it to project a card-aware total before kickoff.
   *
   * Shape: `{ "playerId1": { rarity: "ICONIC", multiplier: 1.6 }, … }`.
   * Empty object when the user has no cards — picker simply skips badges.
   */
  async ownedCardMultipliers(userId: string) {
    const owned = await this.prisma.ownedCard.findMany({
      where: { ownerId: userId },
      select: {
        template: { select: { rarity: true, playerId: true } },
      },
    });
    const rarityRank = new Map<string, number>(
      OWNED_CARD_RARITY_ORDER.map((r, i) => [r, OWNED_CARD_RARITY_ORDER.length - i]),
    );
    const bestByPlayer = new Map<string, string>();
    for (const c of owned) {
      const playerId = c.template.playerId;
      if (!playerId) continue;
      const current = bestByPlayer.get(playerId);
      if (!current || (rarityRank.get(c.template.rarity) ?? 0) > (rarityRank.get(current) ?? 0)) {
        bestByPlayer.set(playerId, c.template.rarity);
      }
    }
    const out: Record<string, { rarity: string; multiplier: number }> = {};
    for (const [playerId, rarity] of bestByPlayer) {
      out[playerId] = {
        rarity,
        multiplier: OWNED_CARD_MULTIPLIER[rarity] ?? 1,
      };
    }
    return out;
  }

  async leaderboard(gameweekId: string, limit = 100) {
    const lineups = await this.prisma.fantasyLineup.findMany({
      where: { gameweekId },
      orderBy: [{ totalPoints: 'desc' }],
      take: limit,
      include: { user: { select: { id: true, displayName: true, photoUrl: true } } },
    });
    return lineups.map((l, i) => ({
      rank: l.rank ?? i + 1,
      userId: l.userId,
      displayName: l.user.displayName,
      photoUrl: l.user.photoUrl,
      points: l.totalPoints,
      budgetUsed: l.budgetUsed,
    }));
  }
}
