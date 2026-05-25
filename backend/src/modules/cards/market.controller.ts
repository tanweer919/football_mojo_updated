import { Controller, Get, Param, Query, Req, UseGuards } from '@nestjs/common';
import { Request } from 'express';
import { CardRarity } from '@prisma/client';
import { OptionalFirebaseAuthGuard } from '../auth/optional-firebase-auth.guard';
import { MarketListInput, MarketService } from './market.service';

/**
 * Public marketplace browse — anonymous-friendly. When a Bearer token is
 * present the response is enriched with per-template "owned by me" counts
 * and the ownership filter becomes meaningful.
 */
@Controller({ path: 'cards/market', version: '1' })
@UseGuards(OptionalFirebaseAuthGuard)
export class MarketController {
  constructor(private readonly market: MarketService) {}

  @Get()
  async list(@Req() req: Request, @Query() q: Record<string, string>) {
    const input: MarketListInput = {
      rarities:  csv(q.rarities) as CardRarity[] | undefined,
      editions:  csv(q.editions),
      positions: csv(q.positions),
      teamIds:   csv(q.teamIds),
      countries: csv(q.countries),
      search:    q.search,
      availability: (q.availability as MarketListInput['availability']) ?? 'all',
      ownership:    (q.ownership    as MarketListInput['ownership'])    ?? 'all',
      sort:         (q.sort         as MarketListInput['sort'])         ?? 'newest',
      cursor: q.cursor || undefined,
      limit:  q.limit ? Number.parseInt(q.limit, 10) : undefined,
    };
    return this.market.list(req.user?.uid ?? null, input);
  }

  @Get('facets')
  facets() {
    return this.market.facets();
  }

  @Get(':templateId')
  detail(@Req() req: Request, @Param('templateId') templateId: string) {
    return this.market.detail(req.user?.uid ?? null, templateId);
  }

  @Get(':templateId/history')
  history(
    @Param('templateId') templateId: string,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.market.history(templateId, {
      cursor,
      limit: limit ? Number.parseInt(limit, 10) : undefined,
    });
  }
}

/// Trim + split a comma-separated query string, dropping empties.
function csv(v: string | undefined): string[] | undefined {
  if (!v) return undefined;
  const parts = v.split(',').map((s) => s.trim()).filter(Boolean);
  return parts.length ? parts : undefined;
}
