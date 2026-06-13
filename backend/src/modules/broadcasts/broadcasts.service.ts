import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../common/prisma.service';

export interface WatchLinkInput {
  name: string;
  url?: string | null;
  countryCode?: string | null;
  countryName?: string | null;
  logoUrl?: string | null;
  position?: number;
}

/** One country's broadcasters — matches the app's MatchBroadcastDto shape. */
interface GroupedBroadcast {
  country: string; // ISO-2 ('' = worldwide/unspecified)
  countryName: string;
  broadcasters: { name: string; url: string | null; logo: string | null }[];
}

@Injectable()
export class BroadcastsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Public payload for `GET /v1/insights/broadcasts/:matchId`.
   * Groups every watch link for the match by country, ordered so named
   * countries come first and "worldwide" (null country) sinks to the end.
   */
  async groupedByMatch(matchId: string): Promise<GroupedBroadcast[]> {
    let links = await this.prisma.watchLink.findMany({
      where: { matchId },
      orderBy: [{ position: 'asc' }, { name: 'asc' }],
    });

    // Fallback: World Cup broadcast coverage is near-identical per country
    // across fixtures, so when a fixture has no links of its own we serve a
    // representative fixture's listings (the best-covered one in the same
    // competition). Public endpoint only — admin still sees the true state.
    if (links.length === 0) {
      links = await this.templateLinks(matchId);
    }

    // Global per-channel link overrides win over the stored url, so an admin
    // can fix "Fox Sports 1" everywhere in one place.
    const overrides = await this.channelOverrideMap();

    const groups = new Map<string, GroupedBroadcast>();
    for (const l of links) {
      const code = (l.countryCode ?? '').toUpperCase();
      const key = code || '_WW';
      if (!groups.has(key)) {
        groups.set(key, {
          country: code,
          countryName: l.countryName ?? (code ? code : 'Worldwide'),
          broadcasters: [],
        });
      }
      groups.get(key)!.broadcasters.push({
        name: l.name,
        url: overrides.get(l.name.trim().toLowerCase()) ?? l.url ?? null,
        logo: l.logoUrl ?? null,
      });
    }

    return [...groups.values()].sort((a, b) => {
      if (!a.country && b.country) return 1; // worldwide last
      if (a.country && !b.country) return -1;
      return a.countryName.localeCompare(b.countryName);
    });
  }

  /**
   * Pick a representative fixture's links to stand in for one that has none.
   * Prefers a pinned fixture (env BROADCAST_TEMPLATE_FIXTURE_ID), else the
   * fixture in the same competition with the most watch links (fullest
   * coverage). Returns [] if nothing is available to borrow from.
   */
  private async templateLinks(matchId: string) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      select: { competitionId: true },
    });

    let templateId = process.env.BROADCAST_TEMPLATE_FIXTURE_ID?.trim() || undefined;
    if (!templateId) {
      const top = await this.prisma.watchLink.groupBy({
        by: ['matchId'],
        where: match?.competitionId ? { match: { competitionId: match.competitionId } } : {},
        _count: { matchId: true },
        orderBy: { _count: { matchId: 'desc' } },
        take: 1,
      });
      templateId = top[0]?.matchId;
    }
    if (!templateId || templateId === matchId) return [];
    return this.prisma.watchLink.findMany({
      where: { matchId: templateId },
      orderBy: [{ position: 'asc' }, { name: 'asc' }],
    });
  }

  // ── Channel overrides (global, name-keyed) ─────────────────────────────────
  /** name(lowercased) → url, applied to every matching WatchLink at serve time. */
  private async channelOverrideMap(): Promise<Map<string, string>> {
    const rows = await this.prisma.channelOverride.findMany();
    return new Map(rows.map((r) => [r.name.trim().toLowerCase(), r.url]));
  }

  listChannelOverrides() {
    return this.prisma.channelOverride.findMany({ orderBy: { name: 'asc' } });
  }

  /**
   * Distinct broadcaster names that currently have NO link anywhere and no
   * override yet — i.e. the channels worth fixing. Sorted by how many fixtures
   * they appear in. Helps the admin know what to add.
   */
  async missingChannels(limit = 100) {
    const [grouped, overrides] = await Promise.all([
      this.prisma.watchLink.groupBy({
        by: ['name'],
        where: { url: null },
        _count: { name: true },
        orderBy: { _count: { name: 'desc' } },
      }),
      this.prisma.channelOverride.findMany({ select: { name: true } }),
    ]);
    const overridden = new Set(overrides.map((o) => o.name.trim().toLowerCase()));
    return grouped
      .filter((g) => !overridden.has(g.name.trim().toLowerCase()))
      .slice(0, limit)
      .map((g) => ({ name: g.name, fixtures: g._count.name }));
  }

  createChannelOverride(input: { name: string; url: string }) {
    return this.prisma.channelOverride.create({
      data: { name: input.name.trim(), url: input.url.trim() },
    });
  }

  async updateChannelOverride(id: string, input: { name: string; url: string }) {
    await this.assertChannelOverride(id);
    return this.prisma.channelOverride.update({
      where: { id },
      data: { name: input.name.trim(), url: input.url.trim() },
    });
  }

  async deleteChannelOverride(id: string) {
    await this.assertChannelOverride(id);
    await this.prisma.channelOverride.delete({ where: { id } });
  }

  private async assertChannelOverride(id: string) {
    const n = await this.prisma.channelOverride.count({ where: { id } });
    if (!n) throw new NotFoundException('channel_override_not_found');
  }

  // ── Admin: fixtures browsing ───────────────────────────────────────────────
  async listFixtures(input: { q?: string; page: number; pageSize: number }) {
    const where = input.q
      ? {
          OR: [
            { homeTeam: { name: { contains: input.q, mode: 'insensitive' as const } } },
            { awayTeam: { name: { contains: input.q, mode: 'insensitive' as const } } },
          ],
        }
      : {};
    const [rows, total] = await Promise.all([
      this.prisma.match.findMany({
        where,
        select: {
          id: true,
          kickoffAt: true,
          status: true,
          homeTeam: { select: { name: true } },
          awayTeam: { select: { name: true } },
          competition: { select: { name: true } },
          _count: { select: { watchLinks: true } },
        },
        orderBy: { kickoffAt: 'desc' },
        take: input.pageSize,
        skip: (input.page - 1) * input.pageSize,
      }),
      this.prisma.match.count({ where }),
    ]);
    return { rows, total };
  }

  async getFixture(matchId: string) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      select: {
        id: true,
        kickoffAt: true,
        status: true,
        homeTeam: { select: { name: true } },
        awayTeam: { select: { name: true } },
        competition: { select: { name: true } },
        watchLinks: { orderBy: [{ position: 'asc' }, { name: 'asc' }] },
      },
    });
    if (!match) throw new NotFoundException('match_not_found');
    return match;
  }

  // ── Admin: watch-link CRUD (source = ADMIN) ────────────────────────────────
  async createLink(matchId: string, input: WatchLinkInput) {
    const exists = await this.prisma.match.count({ where: { id: matchId } });
    if (!exists) throw new NotFoundException('match_not_found');
    return this.prisma.watchLink.create({ data: { matchId, source: 'ADMIN', ...this.clean(input) } });
  }

  async updateLink(id: string, input: WatchLinkInput) {
    await this.assertLink(id);
    return this.prisma.watchLink.update({ where: { id }, data: this.clean(input) });
  }

  async deleteLink(id: string) {
    await this.assertLink(id);
    await this.prisma.watchLink.delete({ where: { id } });
  }

  private async assertLink(id: string) {
    const l = await this.prisma.watchLink.count({ where: { id } });
    if (!l) throw new NotFoundException('watch_link_not_found');
  }

  private clean(input: WatchLinkInput) {
    return {
      name: input.name.trim(),
      url: input.url?.trim() || null,
      countryCode: input.countryCode?.trim().toUpperCase() || null,
      countryName: input.countryName?.trim() || null,
      logoUrl: input.logoUrl?.trim() || null,
      position: input.position ?? 0,
    };
  }

  // ── Scraper ingest (source = SCRAPER) ──────────────────────────────────────
  /**
   * Replaces all SCRAPER links for the given fixtures with the supplied set,
   * leaving curated ADMIN links untouched. `fixtures` is the scraper's
   * `broadcasts_by_fixture.json`: { matchId: [ {country, countryName, broadcasters:[{name,url,logo}]} ] }.
   */
  async ingest(fixtures: Record<string, GroupedBroadcast[]>) {
    let matched = 0;
    let links = 0;
    for (const [matchId, groups] of Object.entries(fixtures)) {
      const exists = await this.prisma.match.count({ where: { id: matchId } });
      if (!exists) continue;
      matched++;
      const rows = groups.flatMap((g, gi) =>
        g.broadcasters.map((b, bi) => ({
          matchId,
          source: 'SCRAPER' as const,
          name: b.name,
          url: b.url ?? null,
          countryCode: (g.country || '').toUpperCase() || null,
          countryName: g.countryName ?? null,
          logoUrl: b.logo ?? null,
          position: gi * 100 + bi,
        })),
      );
      links += rows.length;
      await this.prisma.$transaction([
        this.prisma.watchLink.deleteMany({ where: { matchId, source: 'SCRAPER' } }),
        this.prisma.watchLink.createMany({ data: rows }),
      ]);
    }
    return { matchedFixtures: matched, insertedLinks: links };
  }
}
