import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { fixturePairKey } from '../scores/wc-team-aliases';
import { AiService } from './ai.service';

type MatchRow = Prisma.MatchGetPayload<{
  include: { homeTeam: true; awayTeam: true; competition: true };
}>;

interface Digest {
  content: string;
  sources: unknown;
  generatedAt: Date;
  matchCount: number;
}

/**
 * Tournament-level AI digests for the home "matchday brief":
 *   - today's PREVIEW  — every fixture today + what's at stake. Generated once
 *     per UTC day (first request) and served the rest of the day.
 *   - yesterday's RECAP — all of yesterday's results + what they mean for the
 *     tournament. Generated once and cached forever (results are final).
 * Both are keyed by date in AiContent, so one generation serves every user.
 */
@Injectable()
export class DailyDigestService {
  private readonly log = new Logger(DailyDigestService.name);
  private readonly inflight = new Map<string, Promise<Digest | null>>();

  // WC 2026 is hosted across US time zones, so a "matchday" is a US calendar
  // day, not a UTC one — a late Pacific kickoff (9pm PT) is ~04:00 UTC the next
  // day, which a UTC boundary would split off. The whole tournament
  // (Jun 11 – Jul 19 2026) is in Pacific Daylight Time (UTC-7); midnight PT
  // (~07:00 UTC) lands in the gap between matchdays, so anchoring today/
  // yesterday to UTC-7 keeps a full slate inside one day.
  private static readonly US_OFFSET_MS = 7 * 60 * 60 * 1000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly ai: AiService,
  ) {}

  async getDaily(): Promise<{ preview: Digest | null; recap: Digest | null }> {
    const now = Date.now();
    const today = this.matchday(new Date(now));
    const yesterday = this.matchday(new Date(now - 24 * 60 * 60 * 1000));
    const [preview, recap] = await Promise.all([
      this.build('daily_preview', today).catch((e) => {
        this.log.warn(`preview failed: ${(e as Error).message}`);
        return null;
      }),
      this.build('daily_recap', yesterday).catch((e) => {
        this.log.warn(`recap failed: ${(e as Error).message}`);
        return null;
      }),
    ]);
    return { preview, recap };
  }

  /// US (Pacific) calendar date for an instant — the matchday key.
  private matchday(at: Date): string {
    return new Date(at.getTime() - DailyDigestService.US_OFFSET_MS)
        .toISOString()
        .slice(0, 10);
  }

  private build(type: 'daily_preview' | 'daily_recap', date: string): Promise<Digest | null> {
    const key = `${type}:${date}`;
    const existing = this.inflight.get(key);
    if (existing) return existing;
    const flight = this.doBuild(type, date).finally(() => this.inflight.delete(key));
    this.inflight.set(key, flight);
    return flight;
  }

  private async doBuild(
    type: 'daily_preview' | 'daily_recap',
    date: string,
  ): Promise<Digest | null> {
    const cached = await this.prisma.aiContent.findUnique({
      where: { type_refId: { type, refId: date } },
    });
    if (cached) {
      return {
        content: cached.content,
        sources: cached.sources ?? [],
        generatedAt: cached.updatedAt,
        matchCount: cached.scoreKey ? Number(cached.scoreKey) || 0 : 0,
      };
    }

    const all = await this.matchesOn(date);
    const matches =
      type === 'daily_recap' ? all.filter((m) => m.status === 'FINISHED') : all;
    if (matches.length === 0) return null; // rest day → no card

    const { text, sources, model } = await this.ai.generateGrounded(
      type === 'daily_preview'
        ? this.previewPrompt(matches, date)
        : this.recapPrompt(matches, date),
    );
    const saved = await this.prisma.aiContent.upsert({
      where: { type_refId: { type, refId: date } },
      create: {
        type,
        refId: date,
        content: text,
        sources: sources as unknown as Prisma.InputJsonValue,
        model,
        phase: type,
        scoreKey: String(matches.length), // reuse to stash match count
      },
      update: {
        content: text,
        sources: sources as unknown as Prisma.InputJsonValue,
        model,
      },
    });
    return {
      content: saved.content,
      sources: saved.sources ?? [],
      generatedAt: saved.updatedAt,
      matchCount: matches.length,
    };
  }

  /// Same-fixture rows (WC seed + api-football) deduped by canonical team-pair.
  private async matchesOn(date: string): Promise<MatchRow[]> {
    // `date` is a Pacific calendar date → its UTC window is [00:00 PT, 24:00 PT)
    // i.e. midnight UTC for that date + 7h, spanning 24h.
    const startMs =
        new Date(`${date}T00:00:00Z`).getTime() + DailyDigestService.US_OFFSET_MS;
    const start = new Date(startMs);
    const end = new Date(startMs + 24 * 60 * 60 * 1000 - 1000);
    const rows = await this.prisma.match.findMany({
      where: { kickoffAt: { gte: start, lte: end } },
      include: { homeTeam: true, awayTeam: true, competition: true },
      orderBy: { kickoffAt: 'asc' },
    });
    const seen = new Set<string>();
    const out: MatchRow[] = [];
    for (const m of rows) {
      const k = fixturePairKey(m.homeTeam.name, m.awayTeam.name);
      if (seen.has(k)) continue;
      seen.add(k);
      out.push(m);
    }
    return out;
  }

  private previewPrompt(matches: MatchRow[], date: string): string {
    const lines = matches
      .map((m) => {
        const comp = m.competition?.name ?? m.competitionId;
        const ko = m.kickoffAt.toISOString().slice(11, 16);
        const stage = m.stage ? `, ${m.stage}` : '';
        return `- ${m.homeTeam.name} vs ${m.awayTeam.name} (${comp}${stage}) ${ko} UTC`;
      })
      .join('\n');
    return (
      `You are a sharp football editor writing today's World Cup matchday preview (${date}). ` +
      `Today's fixtures:\n${lines}\n\n` +
      `Preview the day for fans: lead with the must-watch tie, then cover what is at stake in each match — ` +
      `group standings, qualification scenarios, key injuries and the players to watch. Tie it to the bigger ` +
      `tournament picture. Use current information. 150–200 words, plain text, lively but factual. ` +
      `No betting, odds, or predictions of scorelines.`
    );
  }

  private recapPrompt(matches: MatchRow[], date: string): string {
    const lines = matches
      .map((m) => {
        const comp = m.competition?.name ?? m.competitionId;
        return `- ${m.homeTeam.name} ${m.homeScore}-${m.awayScore} ${m.awayTeam.name} (${comp})`;
      })
      .join('\n');
    return (
      `You are a sharp football editor recapping yesterday's World Cup results (${date}). ` +
      `Results:\n${lines}\n\n` +
      `Recap the day: the headline results and any upsets, the standout performers, and — most importantly — ` +
      `what these results mean for the tournament: who has qualified or is on the brink, who is in trouble, ` +
      `and how the groups and knockout picture are shaping up. Use current match reports. ` +
      `150–200 words, plain text, lively but factual. No betting or odds.`
    );
  }
}
