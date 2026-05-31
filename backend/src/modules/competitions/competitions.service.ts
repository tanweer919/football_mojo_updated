import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';
import { isPlaceholderTeamId } from '../../common/team-filters';

/**
 * Single source of truth for "what competitions does this app know about?"
 * The Flutter client reads this list at startup — every UI surface (tabs,
 * chip selectors, fantasy home, tournament screen) is driven by it.
 *
 * Adding a new league post-launch = INSERT a row + run the seed. No app update.
 */
@Injectable()
export class CompetitionsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * All competitions visible to clients. Sorted so the most-relevant one
   * (live or upcoming) comes first — the app uses index 0 as the default.
   */
  async list(opts: { onlyActive?: boolean } = {}) {
    const now = new Date();
    const where = opts.onlyActive ? { endsAt: { gte: now } } : {};

    const competitions = await this.prisma.competition.findMany({
      where,
      include: {
        _count: { select: { matches: true, teams: true } },
        fantasyTournaments: {
          where: { endsAt: { gte: now } },
          select: { id: true, slug: true, name: true, format: true, startsAt: true, endsAt: true },
        },
      },
    });

    return competitions
      .map((c) => ({
        id: c.id,
        name: c.name,
        type: c.type,                                   // 'tournament' | 'league'
        season: c.season,
        startsAt: c.startsAt,
        endsAt: c.endsAt,
        emblemUrl: c.emblemUrl,
        teamCount: c._count.teams,
        matchCount: c._count.matches,
        activeFantasyTournaments: c.fantasyTournaments,
        // Surface-level booleans the client uses to decide what tabs to show.
        // The bracket UI only makes sense for tournament-format competitions.
        showsBracket: c.type === 'tournament',
        showsGroups:  c.type === 'tournament',
        showsStandings: c.type === 'league' || c.type === 'tournament',
        isLive:    c.startsAt <= now && c.endsAt >= now,
        isUpcoming: c.startsAt > now,
      }))
      .sort((a, b) => {
        // Live first (closest to ending), then upcoming (closest to starting), then ended (most recent).
        const ra = rank(a, now);
        const rb = rank(b, now);
        return ra - rb;
      });
  }

  async get(id: string) {
    const c = await this.list();
    const found = c.find((x) => x.id === id);
    if (!found) throw new NotFoundException('competition_not_found');
    return found;
  }

  /** The "primary" active competition the app falls back to when no selection is made. */
  async primary() {
    const all = await this.list({ onlyActive: true });
    return all[0] ?? null;
  }

  /**
   * World Cup-style overview — drives `world-cup.html` hero + opening match
   * + venue/team aggregates. Computed from local data only (no upstream call).
   */
  async overview(id: string) {
    const c = await this.prisma.competition.findUnique({
      where: { id },
      include: {
        _count: { select: { teams: true, matches: true, groups: true } },
      },
    });
    if (!c) throw new NotFoundException('competition_not_found');

    const opening = await this.prisma.match.findFirst({
      where: { competitionId: id },
      orderBy: { kickoffAt: 'asc' },
      include: {
        homeTeam: { select: { id: true, name: true, shortName: true, countryCode: true, crestUrl: true } },
        awayTeam: { select: { id: true, name: true, shortName: true, countryCode: true, crestUrl: true } },
      },
    });

    // Distinct venue list (each unique venue with a match-count rollup).
    const venuesRaw = await this.prisma.match.groupBy({
      by: ['venue'],
      where: { competitionId: id, venue: { not: null } },
      _count: { _all: true },
    });
    const venues = venuesRaw
      .filter((v) => v.venue)
      .map((v) => ({ name: v.venue!, matchCount: v._count._all }))
      .sort((a, b) => b.matchCount - a.matchCount);

    return {
      id: c.id,
      name: c.name,
      type: c.type,
      season: c.season,
      startsAt: c.startsAt,
      endsAt: c.endsAt,
      emblemUrl: c.emblemUrl,
      teamCount: c._count.teams,
      matchCount: c._count.matches,
      groupCount: c._count.groups,
      venueCount: venues.length,
      venues,
      openingMatch: opening,
    };
  }

  /**
   * Groups + standings for a tournament. Drives `world-cup.html` Groups rail.
   * Returns groups in alphabetical order and rows ranked by current position.
   */
  async groups(competitionId: string) {
    const groups = await this.prisma.group.findMany({
      where: { competitionId },
      orderBy: { name: 'asc' },
      include: {
        standings: {
          orderBy: [{ position: 'asc' }, { points: 'desc' }],
          include: {
            team: {
              select: { id: true, name: true, shortName: true, countryCode: true, crestUrl: true },
            },
          },
        },
      },
    });
    return groups.map((g) => ({
      id: g.id,
      name: g.name,
      // "Group A" → "A"
      letter: g.name.replace(/^Group\s+/i, '').trim() || g.name,
      standings: g.standings
        // Hide synthetic placeholder teams (knockout slot labels like
        // "A2", "W74") that ended up in group standings.
        .filter((s) => !isPlaceholderTeamId(s.team.id))
        .map((s) => ({
          position: s.position,
          team: s.team,
          played: s.played,
          won: s.won,
          drawn: s.drawn,
          lost: s.lost,
          goalsFor: s.goalsFor,
          goalsAgainst: s.goalsAg,
          goalDiff: s.goalsFor - s.goalsAg,
          points: s.points,
        })),
    }));
  }
}

function rank(c: { isLive: boolean; isUpcoming: boolean; startsAt: Date; endsAt: Date }, now: Date): number {
  if (c.isLive)     return Math.abs(c.endsAt.getTime() - now.getTime());
  if (c.isUpcoming) return 1_000_000_000 + (c.startsAt.getTime() - now.getTime());
  return 2_000_000_000 + (now.getTime() - c.endsAt.getTime());
}
