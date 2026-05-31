import { Injectable, NotFoundException } from '@nestjs/common';
import { AcquisitionSource, CardRarity, Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';

/**
 * Filter inputs for the cards marketplace list endpoint. All fields optional.
 * Multi-value filters use OR semantics within a field and AND across fields.
 */
export interface MarketListInput {
  rarities?: CardRarity[];
  editions?: string[];
  positions?: string[];      // GK | DEF | MID | FWD
  teamIds?: string[];
  countries?: string[];      // ISO country codes
  search?: string;           // player name substring (case-insensitive)
  availability?: 'all' | 'available' | 'sold_out';
  /// Requires auth — collection vs. catalogue intersection.
  ownership?: 'all' | 'owned' | 'unowned';
  sort?: 'newest' | 'rarity_desc' | 'supply_asc' | 'most_minted' | 'name_asc';
  cursor?: string;           // last templateId from prior page
  limit?: number;            // default 24, max 60
}

/**
 * Marketplace service — read-only browser over the full `CardTemplate`
 * catalogue. Surfaces supply economics (minted/remaining/owners) and the
 * complete chain-of-custody for every OwnedCard instance of a template.
 *
 * No buy/sell here by design (per product brief: "ignore buying and selling
 * cards now"). All mutation paths live in `CardsService` / `TradeService`.
 */
@Injectable()
export class MarketService {
  constructor(private readonly prisma: PrismaService) {}

  // ────────────────────────────────────────────────────────────────────────
  // LIST
  // ────────────────────────────────────────────────────────────────────────

  async list(uid: string | null, input: MarketListInput) {
    const limit = Math.min(Math.max(input.limit ?? 24, 1), 60);
    const where = this._buildWhere(input);
    const orderBy = this._buildOrderBy(input.sort);

    // Cursor pagination: deterministic via (sort key, id) — Prisma handles
    // it natively when we feed the prior page's last id. We over-fetch by 1
    // to detect end-of-list.
    const rows = await this.prisma.cardTemplate.findMany({
      where,
      orderBy,
      take: limit + 1,
      ...(input.cursor ? { cursor: { id: input.cursor }, skip: 1 } : {}),
      include: {
        player: {
          select: {
            id: true, name: true, position: true, photoUrl: true, nationality: true,
            team: { select: { id: true, name: true, shortName: true, crestUrl: true, countryCode: true } },
          },
        },
      },
    });

    const hasMore = rows.length > limit;
    const page = hasMore ? rows.slice(0, limit) : rows;

    // Annotate ownership (count per template) — single grouped query.
    const ownedMap = uid ? await this._ownedCountsFor(uid, page.map((t) => t.id)) : new Map<string, number>();

    let items = page.map((t) => ({
      id: t.id,
      edition: t.edition,
      rarity: t.rarity,
      totalSupply: t.totalSupply,
      mintedCount: t.mintedCount,
      remaining: Math.max(t.totalSupply - t.mintedCount, 0),
      artUrl: t.artUrl,
      frameStyle: t.frameStyle,
      giftableOnly: t.giftableOnly,
      purchasable: t.purchasable,
      gemPrice: t.gemPrice,
      player: t.player == null ? null : {
        id: t.player.id,
        name: t.player.name,
        position: t.player.position,
        photoUrl: t.player.photoUrl,
        country: t.player.nationality,
        team: t.player.team,
      },
      ownedByMe: ownedMap.get(t.id) ?? 0,
    }));

    // Ownership filter has to happen post-query because OwnedCard rows are
    // counted, not joined — pulling it into the WHERE would force a slow
    // EXISTS per row. Catalogue is small enough (~thousands) that filtering
    // a page is fine.
    if (uid && input.ownership === 'owned') items = items.filter((i) => i.ownedByMe > 0);
    if (uid && input.ownership === 'unowned') items = items.filter((i) => i.ownedByMe === 0);

    return {
      items,
      nextCursor: hasMore ? page[page.length - 1]!.id : null,
    };
  }

  /// Aggregated facet counts for the filter sheet. Single trip per facet
  /// dimension; cached by Nest's cache-manager upstream if wired.
  async facets() {
    const [byRarity, byEdition, byPosition, byCountry, teams] = await Promise.all([
      this.prisma.cardTemplate.groupBy({
        by: ['rarity'],
        _count: { _all: true },
      }),
      this.prisma.cardTemplate.groupBy({
        by: ['edition'],
        _count: { _all: true },
        orderBy: { edition: 'asc' },
      }),
      this.prisma.$queryRaw<Array<{ position: string | null; count: bigint }>>(Prisma.sql`
        SELECT p."position", COUNT(*)::bigint AS count
          FROM "CardTemplate" t
          JOIN "Player" p ON p.id = t."playerId"
         WHERE p."position" IS NOT NULL
         GROUP BY p."position"
         ORDER BY count DESC
      `),
      this.prisma.$queryRaw<Array<{ nationality: string | null; count: bigint }>>(Prisma.sql`
        SELECT p."nationality", COUNT(*)::bigint AS count
          FROM "CardTemplate" t
          JOIN "Player" p ON p.id = t."playerId"
         WHERE p."nationality" IS NOT NULL
         GROUP BY p."nationality"
         ORDER BY count DESC
         LIMIT 60
      `),
      // Teams that have at least one card template — caps result set.
      this.prisma.$queryRaw<Array<{ id: string; name: string; shortName: string; crestUrl: string | null; count: bigint }>>(Prisma.sql`
        SELECT t.id, t.name, t."shortName", t."crestUrl", COUNT(*)::bigint AS count
          FROM "Team" t
          JOIN "Player" p ON p."teamId" = t.id
          JOIN "CardTemplate" c ON c."playerId" = p.id
         GROUP BY t.id, t.name, t."shortName", t."crestUrl"
         ORDER BY count DESC
         LIMIT 120
      `),
    ]);

    return {
      rarities: byRarity.map((r) => ({ value: r.rarity, count: r._count._all })),
      editions: byEdition.map((e) => ({ value: e.edition, count: e._count._all })),
      positions: byPosition.map((p) => ({ value: p.position, count: Number(p.count) })),
      countries: byCountry.map((c) => ({ value: c.nationality, count: Number(c.count) })),
      teams: teams.map((t) => ({
        id: t.id, name: t.name, shortName: t.shortName, crestUrl: t.crestUrl, count: Number(t.count),
      })),
    };
  }

  // ────────────────────────────────────────────────────────────────────────
  // DETAIL
  // ────────────────────────────────────────────────────────────────────────

  async detail(uid: string | null, templateId: string) {
    const t = await this.prisma.cardTemplate.findUnique({
      where: { id: templateId },
      include: {
        player: { include: { team: true } },
        setMemberships: { include: { set: { select: { id: true, name: true } } } },
      },
    });
    if (!t) throw new NotFoundException('template_not_found');

    // Supply stats — aggregated in a single round-trip.
    const owned = await this.prisma.ownedCard.findMany({
      where: { templateId },
      select: { id: true, serialNumber: true, mintedAt: true, ownerId: true, acquiredVia: true },
    });
    const serials = owned.map((o) => o.serialNumber);
    const owners = new Set(owned.map((o) => o.ownerId));
    const mintedAts = owned.map((o) => o.mintedAt.getTime());

    const myCopies = uid
      ? owned
          .filter((o) => o.ownerId === uid)
          .map((o) => ({ id: o.id, serialNumber: o.serialNumber, acquiredVia: o.acquiredVia, mintedAt: o.mintedAt }))
          .sort((a, b) => a.serialNumber - b.serialNumber)
      : [];

    // Player form data — last scores + averages. Uses PlayerGameweekScore
    // when available (post-WC), falls back to seasonRating from PlayerValuation
    // (pre-WC, populated by `npm run ingest:form`).
    const playerId = t.player?.id;
    let playerForm: Record<string, unknown> | null = null;
    if (playerId) {
      const avg = (arr: number[]) =>
        arr.length ? Math.round((arr.reduce((s, x) => s + x, 0) / arr.length) * 10) / 10 : 0;

      const lastScores = await this.prisma.playerGameweekScore.findMany({
        where: { playerId },
        orderBy: { updatedAt: 'desc' },
        take: 10,
        include: { gameweek: { select: { number: true } } },
      });

      const last40 = await this.prisma.playerGameweekScore.findMany({
        where: { playerId },
        orderBy: { updatedAt: 'desc' },
        take: 40,
        select: { totalPoints: true },
      });
      const pts40 = last40.map((s) => s.totalPoints);

      if (pts40.length > 0) {
        playerForm = {
          formStats: {
            last5:  { avg: avg(pts40.slice(0, 5)),  n: Math.min(5,  pts40.length) },
            last10: { avg: avg(pts40.slice(0, 10)), n: Math.min(10, pts40.length) },
            last40: { avg: avg(pts40),              n: pts40.length },
          },
          lastScores: lastScores.map((s) => ({
            gameweekId: s.gameweekId,
            gameweekNumber: s.gameweek?.number ?? null,
            totalPoints: s.totalPoints,
            breakdown: s.breakdown,
            updatedAt: s.updatedAt,
          })),
        };
      } else {
        // Pre-WC fallback: use seasonRating from PlayerValuation
        const val = await this.prisma.playerValuation.findUnique({
          where: { playerId },
          select: { seasonRating: true, seasonGoals: true, seasonAssists: true, seasonAppearances: true },
        });
        if (val?.seasonRating != null) {
          // Convert 0–10 rating to a 0–100 score for consistent display
          const score = Math.round(val.seasonRating! * 10);
          const apps = val.seasonAppearances ?? 0;
          playerForm = {
            formStats: {
              last5:  { avg: score, n: Math.min(5, apps) },
              last10: { avg: score, n: Math.min(10, apps) },
              last40: { avg: score, n: Math.min(40, apps) },
            },
            lastScores: [],
          };
        }
      }
    }

    return {
      template: {
        id: t.id,
        edition: t.edition,
        rarity: t.rarity,
        totalSupply: t.totalSupply,
        mintedCount: t.mintedCount,
        remaining: Math.max(t.totalSupply - t.mintedCount, 0),
        artUrl: t.artUrl,
        frameStyle: t.frameStyle,
        giftableOnly: t.giftableOnly,
        purchasable: t.purchasable,
        gemPrice: t.gemPrice,
        baseStats: t.baseStats,
        createdAt: t.createdAt,
      },
      player: t.player == null ? null : {
        id: t.player.id,
        name: t.player.name,
        position: t.player.position,
        photoUrl: t.player.photoUrl,
        country: t.player.nationality,
        shirtNumber: t.player.shirtNumber,
        team: t.player.team,
      },
      sets: t.setMemberships.map((m) => m.set),
      stats: {
        totalSupply: t.totalSupply,
        mintedCount: owned.length,
        remaining: Math.max(t.totalSupply - owned.length, 0),
        uniqueOwners: owners.size,
        lowestSerial: serials.length ? Math.min(...serials) : null,
        highestSerial: serials.length ? Math.max(...serials) : null,
        firstMintedAt: mintedAts.length ? new Date(Math.min(...mintedAts)) : null,
        lastMintedAt:  mintedAts.length ? new Date(Math.max(...mintedAts)) : null,
        ownedByMe: myCopies.length,
      },
      myCopies,
      playerForm,
    };
  }

  // ────────────────────────────────────────────────────────────────────────
  // HISTORY
  // ────────────────────────────────────────────────────────────────────────

  /**
   * Full chain-of-custody for every OwnedCard instance of this template.
   *
   * Combines two event sources, returned as a single sorted timeline:
   *   1. MINT — one per OwnedCard (mintedAt, firstOwner, acquiredVia)
   *   2. TRADE — every ACCEPTED Trade that involved one of these OwnedCards.
   *
   * Trade.offered/requested are stored as JSON arrays of {ownedCardId}; we
   * query via Postgres JSONB containment to avoid pulling the whole trades
   * table into memory.
   */
  async history(templateId: string, opts: { limit?: number; cursor?: string } = {}) {
    const limit = Math.min(Math.max(opts.limit ?? 50, 1), 200);

    const owned = await this.prisma.ownedCard.findMany({
      where: { templateId },
      select: { id: true, serialNumber: true, mintedAt: true, firstOwnerId: true, acquiredVia: true },
      orderBy: { mintedAt: 'desc' },
    });
    if (owned.length === 0) return { events: [], nextCursor: null };

    const ownedIds = owned.map((o) => o.id);
    const serialByOwned = new Map(owned.map((o) => [o.id, o.serialNumber]));

    // Trades that reference any ownedCard of this template, on either side.
    // Postgres JSONB `@>` containment query — needs an `ANY` over our id list.
    const trades = await this.prisma.$queryRaw<Array<{
      id: string;
      initiatorId: string;
      recipientId: string;
      offered: { ownedCardId: string }[];
      requested: { ownedCardId: string }[];
      status: string;
      resolvedAt: Date | null;
      createdAt: Date;
    }>>(Prisma.sql`
      SELECT id, "initiatorId", "recipientId", offered, requested, status, "resolvedAt", "createdAt"
        FROM "Trade"
       WHERE status = 'ACCEPTED'
         AND (
           offered @> ANY(ARRAY(SELECT jsonb_build_array(jsonb_build_object('ownedCardId', x)) FROM unnest(${ownedIds}::text[]) AS x))
           OR
           requested @> ANY(ARRAY(SELECT jsonb_build_array(jsonb_build_object('ownedCardId', x)) FROM unnest(${ownedIds}::text[]) AS x))
         )
       ORDER BY "resolvedAt" DESC NULLS LAST
       LIMIT 500
    `);

    // Resolve every unique user id referenced across both event types — one
    // batch query so we don't N+1 the user table.
    const userIds = new Set<string>();
    for (const o of owned) userIds.add(o.firstOwnerId);
    for (const t of trades) { userIds.add(t.initiatorId); userIds.add(t.recipientId); }

    const users = await this.prisma.user.findMany({
      where: { id: { in: [...userIds] } },
      select: { id: true, userTag: true, displayName: true, photoUrl: true },
    });
    const userMap = new Map(users.map((u) => [u.id, u]));

    type Event =
      | {
          type: 'MINT';
          at: Date;
          ownedCardId: string;
          serialNumber: number;
          acquiredVia: AcquisitionSource;
          actor: { id: string; userTag: string | null; displayName: string | null; photoUrl: string | null } | null;
        }
      | {
          type: 'TRADE';
          at: Date;
          tradeId: string;
          fromUser: { id: string; userTag: string | null; displayName: string | null; photoUrl: string | null } | null;
          toUser: { id: string; userTag: string | null; displayName: string | null; photoUrl: string | null } | null;
          ownedCardIds: string[];
          serialNumbers: number[];
        };

    const events: Event[] = [];
    for (const o of owned) {
      events.push({
        type: 'MINT',
        at: o.mintedAt,
        ownedCardId: o.id,
        serialNumber: o.serialNumber,
        acquiredVia: o.acquiredVia,
        actor: userMap.get(o.firstOwnerId) ?? null,
      });
    }
    for (const t of trades) {
      const offeredHere = (t.offered ?? []).map((x) => x.ownedCardId).filter((id) => serialByOwned.has(id));
      const requestedHere = (t.requested ?? []).map((x) => x.ownedCardId).filter((id) => serialByOwned.has(id));

      // Two directional events per trade: cards moving initiator → recipient
      // (the `offered` side) and cards moving recipient → initiator (the
      // `requested` side). Only emit a side if some of those cards belong to
      // this template.
      if (offeredHere.length) {
        events.push({
          type: 'TRADE',
          at: t.resolvedAt ?? t.createdAt,
          tradeId: t.id,
          fromUser: userMap.get(t.initiatorId) ?? null,
          toUser:   userMap.get(t.recipientId) ?? null,
          ownedCardIds: offeredHere,
          serialNumbers: offeredHere.map((id) => serialByOwned.get(id)!),
        });
      }
      if (requestedHere.length) {
        events.push({
          type: 'TRADE',
          at: t.resolvedAt ?? t.createdAt,
          tradeId: t.id,
          fromUser: userMap.get(t.recipientId) ?? null,
          toUser:   userMap.get(t.initiatorId) ?? null,
          ownedCardIds: requestedHere,
          serialNumbers: requestedHere.map((id) => serialByOwned.get(id)!),
        });
      }
    }

    events.sort((a, b) => b.at.getTime() - a.at.getTime());

    // Cursor: pagination on a unified timeline is awkward; instead we slice
    // by index for now. Clients fetch first page (~50) and expand on demand.
    const startIdx = opts.cursor ? Number.parseInt(opts.cursor, 10) || 0 : 0;
    const slice = events.slice(startIdx, startIdx + limit);
    const nextCursor = startIdx + limit < events.length ? String(startIdx + limit) : null;

    return { events: slice, nextCursor, total: events.length };
  }

  // ────────────────────────────────────────────────────────────────────────
  // INTERNAL
  // ────────────────────────────────────────────────────────────────────────

  private _buildWhere(i: MarketListInput): Prisma.CardTemplateWhereInput {
    const AND: Prisma.CardTemplateWhereInput[] = [];

    // Always exclude templates without a player — set-master / reward-only
    // cards that have no playerId show up as blank "untitled" cards.
    AND.push({ playerId: { not: null } });

    if (i.rarities?.length) AND.push({ rarity: { in: i.rarities } });

    // When no edition filter is provided, default to the BASE edition so
    // the grid doesn't show the same player 7x (once per stage edition).
    // Users can explicitly select stage editions from the filter sheet.
    if (i.editions?.length) {
      AND.push({ edition: { in: i.editions } });
    } else {
      AND.push({ edition: 'WC2026-BASE' });
    }

    if (i.availability === 'available') {
      AND.push({ mintedCount: { lt: this.prisma.cardTemplate.fields.totalSupply } });
    }
    if (i.availability === 'sold_out') {
      AND.push({ mintedCount: { gte: this.prisma.cardTemplate.fields.totalSupply } });
    }

    const playerWhere: Prisma.PlayerWhereInput = {};
    if (i.positions?.length) playerWhere.position = { in: i.positions };
    if (i.countries?.length) playerWhere.nationality = { in: i.countries };
    if (i.teamIds?.length) playerWhere.teamId = { in: i.teamIds };
    if (i.search?.trim()) playerWhere.name = { contains: i.search.trim(), mode: 'insensitive' };
    if (Object.keys(playerWhere).length) AND.push({ player: playerWhere });

    return AND.length ? { AND } : {};
  }

  private _buildOrderBy(sort?: MarketListInput['sort']): Prisma.CardTemplateOrderByWithRelationInput[] {
    // Secondary sort by `id` keeps cursor pagination deterministic when the
    // primary key isn't unique (e.g. two templates with the same rarity).
    switch (sort) {
      case 'rarity_desc':  return [{ rarity: 'desc' }, { id: 'asc' }];
      case 'supply_asc':   return [{ totalSupply: 'asc' }, { id: 'asc' }];
      case 'most_minted':  return [{ mintedCount: 'desc' }, { id: 'asc' }];
      case 'name_asc':     return [{ player: { name: 'asc' } }, { id: 'asc' }];
      case 'newest':
      default:             return [{ createdAt: 'desc' }, { id: 'asc' }];
    }
  }

  private async _ownedCountsFor(uid: string, templateIds: string[]): Promise<Map<string, number>> {
    if (!templateIds.length) return new Map();
    const rows = await this.prisma.ownedCard.groupBy({
      by: ['templateId'],
      where: { ownerId: uid, templateId: { in: templateIds } },
      _count: { _all: true },
    });
    return new Map(rows.map((r) => [r.templateId, r._count._all]));
  }
}
