import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../common/prisma.service';
import { ApiFootballCacheService } from '../api-football/api-football-cache.service';
import { AiService } from './ai.service';

const TYPE = 'match_preview';

// Lifecycle timings.
const PRE_REFRESH_MS = 30 * 60 * 1000; // regenerate the preview this long before KO
const EARLY_TTL_MS = 12 * 60 * 60 * 1000; // safety refresh for a preview made very early
const LIVE_TTL_MS = 10 * 60 * 1000; // live summary refresh for non-goal developments
const SCORE_DEBOUNCE_MS = 2 * 60 * 1000; // min gap between goal-triggered regenerations
const FINAL_DELAY_MS = 8 * 60 * 1000; // wait after FT for match reports to surface

type Phase = 'preview' | 'preview_imminent' | 'live' | 'final' | 'final_provisional';

type MatchRow = Prisma.MatchGetPayload<{
  include: { homeTeam: true; awayTeam: true; competition: true };
}>;

/**
 * On-demand AI content for a match, cached per match and evolving through the
 * match lifecycle:
 *   - > 30 min before KO  → PREVIEW (form, injuries, H2H, stakes)
 *   - last 30 min → KO     → a single refreshed PREVIEW (confirmed XI, late news)
 *   - LIVE / HT            → SUMMARY refreshed every 10 min (scoreline + events
 *                            + stats + grounding)
 *   - FINISHED             → final SUMMARY cached forever, generated ~8 min
 *                            after FT so post-match reports exist to ground on.
 * First caller generates; everyone else (until the phase's window elapses) is
 * served the cached copy, so credits aren't burned per user.
 */
@Injectable()
export class MatchPreviewService {
  private readonly log = new Logger(MatchPreviewService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ai: AiService,
    private readonly apiCache: ApiFootballCacheService,
  ) {}

  async getPreview(matchId: string) {
    const match = await this.prisma.match.findUnique({
      where: { id: matchId },
      include: { homeTeam: true, awayTeam: true, competition: true },
    });
    if (!match) throw new NotFoundException('match_not_found');

    const cached = await this.prisma.aiContent.findUnique({
      where: { type_refId: { type: TYPE, refId: matchId } },
    });
    const now = Date.now();
    const ko = match.kickoffAt.getTime();
    const st = match.status;

    // ── LIVE ────────────────────────────────────────────────────────────────
    if (st === 'LIVE' || st === 'HALF_TIME') {
      const score = `${match.homeScore}-${match.awayScore}`;
      if (cached?.phase === 'live') {
        const age = now - cached.updatedAt.getTime();
        const scoreChanged = cached.scoreKey !== score;
        // Refresh on a goal (debounced so a flurry only regenerates once), and
        // periodically for non-goal developments (cards, momentum) at the TTL.
        const fresh = age < LIVE_TTL_MS && (!scoreChanged || age < SCORE_DEBOUNCE_MS);
        if (fresh) return this.shape(cached);
      }
      return this.generate(match, 'live');
    }

    // ── FINISHED / CANCELLED ────────────────────────────────────────────────
    if (st === 'FINISHED' || st === 'CANCELLED') {
      if (cached?.phase === 'final') return this.shape(cached); // permanent
      // `updatedAt` freezes at ~FT (the match stops changing once final), so
      // it's a good proxy for the final whistle.
      const finalReady = now - match.updatedAt.getTime() >= FINAL_DELAY_MS;
      if (!finalReady && cached) return this.shape(cached); // serve last summary meanwhile
      return this.generate(match, finalReady ? 'final' : 'final_provisional');
    }

    // ── UPCOMING (SCHEDULED / POSTPONED / TBD) ──────────────────────────────
    if (now < ko - PRE_REFRESH_MS) {
      const fresh =
        cached &&
        (cached.phase === 'preview' || cached.phase === 'preview_imminent') &&
        now - cached.updatedAt.getTime() < EARLY_TTL_MS;
      return fresh ? this.shape(cached) : this.generate(match, 'preview');
    }
    // Final 30 minutes: one refreshed preview with confirmed XI / late news.
    if (cached?.phase === 'preview_imminent') return this.shape(cached);
    return this.generate(match, 'preview_imminent');
  }

  // Single-flight: coalesce concurrent generations for the same match into one
  // Gemini call. After a goal, dozens of users may tap "generate" at once — this
  // makes that one upstream call (and one credit), not N.
  private readonly inflight = new Map<string, Promise<ReturnType<MatchPreviewService['shape']>>>();

  private generate(match: MatchRow, phase: Phase) {
    const existing = this.inflight.get(match.id);
    if (existing) return existing;
    const flight = this.doGenerate(match, phase).finally(() =>
      this.inflight.delete(match.id),
    );
    this.inflight.set(match.id, flight);
    return flight;
  }

  private async doGenerate(match: MatchRow, phase: Phase) {
    const prompt =
      phase === 'live' || phase === 'final' || phase === 'final_provisional'
        ? await this.buildSummaryPrompt(match, phase)
        : this.buildPreviewPrompt(match, phase);

    const { text, sources, model } = await this.ai.generateGrounded(prompt);
    const sourcesJson = sources as unknown as Prisma.InputJsonValue;
    const scoreKey = `${match.homeScore}-${match.awayScore}`;
    const saved = await this.prisma.aiContent.upsert({
      where: { type_refId: { type: TYPE, refId: match.id } },
      create: { type: TYPE, refId: match.id, content: text, sources: sourcesJson, model, phase, scoreKey },
      update: { content: text, sources: sourcesJson, model, phase, scoreKey },
    });
    return this.shape(saved);
  }

  private shape(c: { content: string; sources: unknown; model: string; updatedAt: Date; phase: string | null }) {
    const isSummary =
      c.phase === 'live' || c.phase === 'final' || c.phase === 'final_provisional';
    return {
      content: c.content,
      sources: c.sources ?? [],
      model: c.model,
      generatedAt: c.updatedAt,
      kind: isSummary ? 'summary' : 'preview',
      phase: c.phase,
    };
  }

  // ── Prompts ───────────────────────────────────────────────────────────────

  private buildPreviewPrompt(m: MatchRow, phase: Phase): string {
    const comp = m.competition?.name ?? m.competitionId;
    const venue = m.venue ? ` at ${m.venue}` : '';
    const ko = m.kickoffAt.toISOString().slice(0, 16).replace('T', ' ') + ' UTC';

    if (phase === 'preview_imminent') {
      return (
        `You are an expert football analyst writing the final pre-match briefing about 30 minutes before kick-off. ` +
        `Match: ${m.homeTeam.name} vs ${m.awayTeam.name} (${comp})${venue}, kicking off ${ko}. ` +
        `Lead with the very latest: confirmed or strongly-expected starting line-ups, any late injury, suspension or rotation news, and the immediate stakes. ` +
        `Then add recent form (last 4–6 games) and the tactical match-up that will decide it. ` +
        `Search for and use current information; do not invent line-ups you cannot verify. ` +
        `Write 120–160 words of plain text, confident and neutral — no clichés, no betting tips or odds. ` +
        `End with a single line beginning "Key battle:" naming the duel that could swing the game.`
      );
    }
    return (
      `You are an expert football analyst writing a sharp, factual pre-match preview. ` +
      `Match: ${m.homeTeam.name} vs ${m.awayTeam.name} (${comp})${venue}, kicking off ${ko}. ` +
      `Use up-to-date information: recent form over the last 4–6 games, the competition context and what is at stake, head-to-head history, key injuries or suspensions, and the likely tactical approach of each side. ` +
      `Write 120–160 words of plain text, confident and neutral — no clichés, no hedging, no betting tips or odds. ` +
      `End with a single line beginning "Key battle:" naming the match-up that could decide it.`
    );
  }

  private async buildSummaryPrompt(m: MatchRow, phase: Phase): Promise<string> {
    const comp = m.competition?.name ?? m.competitionId;
    const venue = m.venue ? ` at ${m.venue}` : '';
    const facts = await this.assembleFacts(m);
    const live = phase === 'live';

    const header = live
      ? `You are an expert football analyst writing a live "what has happened so far" summary of a match in progress.`
      : `You are an expert football analyst writing the definitive post-match report of a finished game.`;

    const subject = live
      ? `Match: ${m.homeTeam.name} ${m.homeScore}-${m.awayScore} ${m.awayTeam.name} (${comp}), currently ${this.minuteLabel(m)}.`
      : `Final result: ${m.homeTeam.name} ${m.homeScore}-${m.awayScore} ${m.awayTeam.name} (${comp})${venue}.`;

    const ask = live
      ? `Using ONLY the facts below plus current information, describe how the match is unfolding: who is on top and why (lean on the xG and shot numbers if present, not just possession), the decisive moments so far, the momentum, and what to watch for the rest of the game. ` +
        `Write 110–150 words of plain text, accurate and neutral.`
      : `Using the facts below plus current match reports, write the definitive post-match analysis. Cover, in flowing prose (not headings): ` +
        `(1) a sharp one-line verdict on the result; ` +
        `(2) the story of the game — decisive moments and goals with scorers and minutes; ` +
        `(3) what the underlying numbers say — read the expected goals (xG) against the actual scoreline and judge whether the win was deserved, a smash-and-grab, or against the run of play (ONLY if xG appears in the facts; never invent it); ` +
        `(4) the standout performer and the turning point; ` +
        `(5) what the result means in the competition. ` +
        `Then end with ONE striking, non-obvious insight a casual viewer would miss — a quirk in the data (e.g. heavy xG over/under-performance, shot dominance that didn't convert, a goalkeeper bailing out a side) or a genuine record/streak/historical rarity from your sources — on its own final line prefixed exactly "Beyond the box score: ". ` +
        `Write 150–200 words of plain text, authoritative and neutral.`;

    return (
      `${header}\n${subject}\n\n` +
      `Match facts so far:\n${facts}\n\n` +
      `${ask} Treat the listed stats and events as ground truth; do not invent events, scorers, xG or other stats that are not in the facts or supported by your sources. No betting tips or odds.`
    );
  }

  private minuteLabel(m: MatchRow): string {
    if (m.status === 'HALF_TIME') return 'half-time';
    const base = m.minute ?? 0;
    return m.minuteExtra ? `${base}+${m.minuteExtra}'` : `${base}'`;
  }

  /// Build a compact, factual bullet list from the live scoreline, key events
  /// (goals + cards) and team stats. Falls back to the scoreline alone if the
  /// fixture has no numeric api-football id or the upstream fetch fails.
  private async assembleFacts(m: MatchRow): Promise<string> {
    const lines: string[] = [
      `Score: ${m.homeTeam.name} ${m.homeScore}-${m.awayScore} ${m.awayTeam.name} (${this.minuteLabel(m)}).`,
    ];
    if (!/^\d+$/.test(m.id)) return lines.join('\n');

    const fixtureId = Number(m.id);
    try {
      const events = await this.apiCache.fixtureEvents(fixtureId);
      const goalCards = events
        .filter((e) => e.type === 'Goal' || e.type === 'Card')
        .map((e) => {
          const min = `${e.time.elapsed}${e.time.extra ? `+${e.time.extra}` : ''}'`;
          const who = e.player?.name ?? 'Unknown';
          const label = e.type === 'Goal' ? `Goal${e.detail ? ` (${e.detail})` : ''}` : e.detail;
          return `- ${min} ${label} — ${who} (${e.team.name})`;
        });
      if (goalCards.length) lines.push('Events:', ...goalCards);
    } catch (e) {
      this.log.warn(`events fetch failed for ${m.id}: ${(e as Error).message}`);
    }

    try {
      const stats = await this.apiCache.fixtureStatistics(fixtureId);
      const pick = (teamId: string) =>
        stats.find((s) => String(s.team.id) === teamId)?.statistics ?? [];
      const home = pick(m.homeTeam.id);
      const away = pick(m.awayTeam.id);
      const raw = (arr: typeof home, type: string) =>
        arr.find((s) => s.type === type)?.value ?? null;
      const val = (arr: typeof home, type: string) => raw(arr, type) ?? '—';
      const row = (label: string, type: string) =>
        `- ${label}: ${val(home, type)} vs ${val(away, type)}`;
      if (home.length || away.length) {
        lines.push(
          'Team stats (home vs away):',
          row('Possession', 'Ball Possession'),
          row('Expected goals (xG)', 'expected_goals'),
          row('Total shots', 'Total Shots'),
          row('Shots on target', 'Shots on Goal'),
          row('Shots inside box', 'Shots insidebox'),
          row('Goalkeeper saves', 'Goalkeeper Saves'),
          row('Corners', 'Corner Kicks'),
          row('Passing accuracy', 'Passes %'),
        );
        // Explicit xG-vs-result read — the "deserved or lucky" signal that's the
        // headline insight a viewer can't compute in their head. Only when both
        // sides report xG (api-football coverage varies).
        const hx = parseFloat(String(raw(home, 'expected_goals') ?? ''));
        const ax = parseFloat(String(raw(away, 'expected_goals') ?? ''));
        if (Number.isFinite(hx) && Number.isFinite(ax)) {
          const favours =
            Math.abs(hx - ax) < 0.2
              ? 'the xG was even'
              : `xG favoured ${hx > ax ? m.homeTeam.name : m.awayTeam.name}`;
          lines.push(
            `xG read: ${m.homeTeam.name} ${hx.toFixed(2)} – ${ax.toFixed(2)} ${m.awayTeam.name} ` +
              `vs actual goals ${m.homeScore}-${m.awayScore} (${favours}).`,
          );
        }
      }
    } catch (e) {
      this.log.warn(`stats fetch failed for ${m.id}: ${(e as Error).message}`);
    }

    return lines.join('\n');
  }
}
