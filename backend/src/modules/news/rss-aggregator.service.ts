import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Interval } from '@nestjs/schedule';
import { createHash } from 'crypto';
import Parser from 'rss-parser';
import { PrismaService } from '../../common/prisma.service';
import { PushService } from '../notifications/push.service';

type Item = Parser.Item & { 'media:content'?: { $: { url: string } }; enclosure?: { url?: string } };

// Self-hosted RSS aggregator. Reliable, free, legal — publishers opt in to RSS.
// Replaces the old Django Bing-scraper completely.
@Injectable()
export class RssAggregatorService implements OnModuleInit {
  private readonly log = new Logger(RssAggregatorService.name);
  private readonly parser = new Parser<{}, Item>({
    timeout: 20_000,
    headers: { 'User-Agent': 'FootballMojo/1.0 (+https://footballmojo.app)' },
  });
  private readonly feeds: string[];
  private readonly intervalMs: number;
  private running = false;

  // Team-name → id index for tagging articles. Refreshed before each
  // refresh pass so newly seeded teams start matching immediately.
  // Map entries are pre-lowercased; value is the canonical Team.id.
  private teamMatchIndex: Array<{ pattern: RegExp; teamId: string }> = [];

  constructor(
    cfg: ConfigService,
    private readonly prisma: PrismaService,
    private readonly push: PushService,
  ) {
    this.feeds = cfg.getOrThrow<string>('NEWS_RSS_FEEDS').split(',').map((s) => s.trim()).filter(Boolean);
    this.intervalMs = +(cfg.get('NEWS_REFRESH_INTERVAL_MS') ?? 600_000);
  }

  async onModuleInit() {
    // Kick off once on boot; subsequent runs are driven by @Interval below.
    this.refresh().catch((e) => this.log.error('initial refresh failed', e));
  }

  /// Build a name-match index from every team in the DB. Called before each
  /// refresh so teams added after boot get matched on the next cycle.
  /// Uses word-boundary regex so "Roma" matches "AS Roma 2-0..." but not
  /// "roman" / "Romania". Common short names (Man Utd, Man City, ManU,
  /// Barca, Spurs) are added on top of the canonical name + shortName.
  private async loadTeamMatchIndex(): Promise<void> {
    const teams = await this.prisma.team.findMany({
      select: { id: true, name: true, shortName: true },
    });

    // Manual alias table for the most-mentioned common-name divergences.
    // Lower-case keys; values are appended to the team's match list.
    const aliasMap: Record<string, string[]> = {
      'manchester united': ['Man Utd', 'Man United', 'ManU', 'MUFC'],
      'manchester city':   ['Man City', 'MCFC'],
      'tottenham hotspur': ['Spurs', 'Tottenham'],
      'wolverhampton wanderers': ['Wolves'],
      'newcastle united':  ['Newcastle'],
      'fc barcelona':      ['Barça', 'Barca', 'FCB'],
      'real madrid cf':    ['Real Madrid', 'Madrid'],
      'paris saint germain': ['PSG', 'Paris SG'],
      'borussia dortmund': ['BVB', 'Dortmund'],
      'bayern munich':     ['Bayern'],
      'bayern münchen':    ['Bayern', 'Bayern Munich'],
      'fc internazionale milano': ['Inter', 'Inter Milan'],
      'ac milan':          ['AC Milan'],
      'juventus':          ['Juve'],
      'as roma':           ['Roma'],
      'olympique de marseille': ['Marseille', 'OM'],
      'olympique lyonnais': ['Lyon', 'OL'],
    };

    const index: Array<{ pattern: RegExp; teamId: string }> = [];
    for (const t of teams) {
      const names = new Set<string>();
      if (t.name) names.add(t.name);
      if (t.shortName) names.add(t.shortName);
      const extra = aliasMap[t.name.toLowerCase()] ?? [];
      for (const e of extra) names.add(e);

      for (const n of names) {
        const trimmed = n.trim();
        // Skip 1–2 char "names" — too many false positives.
        if (trimmed.length < 3) continue;
        // Word-boundary, case-insensitive. Escape regex metachars in the name.
        const escaped = trimmed.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        index.push({
          pattern: new RegExp(`\\b${escaped}\\b`, 'i'),
          teamId: t.id,
        });
      }
    }
    this.teamMatchIndex = index;
    this.log.log(`team match index: ${index.length} patterns across ${teams.length} teams`);
  }

  /// Scan an article's title + summary for team mentions. Returns up to
  /// 6 matched team IDs (caps the noise from articles that namedrop ten
  /// rivals in a transfer-rumour piece).
  private matchTeams(title: string, summary: string | null): string[] {
    if (this.teamMatchIndex.length === 0) return [];
    const haystack = `${title}\n${summary ?? ''}`;
    const matched = new Set<string>();
    for (const { pattern, teamId } of this.teamMatchIndex) {
      if (matched.has(teamId)) continue;
      if (pattern.test(haystack)) matched.add(teamId);
      if (matched.size >= 6) break;
    }
    return [...matched];
  }

  // ── Football relevance gate ───────────────────────────────────────────────
  // Some configured feeds are general-sport, so tennis/cricket/NBA/etc. leak
  // in. We keep an article only when it's football-relevant: a known football
  // team matched, OR it reads as football, OR it has no other-sport signal.
  // We only DROP when there's a clear other-sport signal and no football one —
  // so ambiguous/short football pieces are never wrongly filtered.
  private static readonly OTHER_SPORT_RE =
    /\b(tennis|atp|wta|wimbledon|roland.?garros|grand slam|cricket|ipl\b|t20|odi\b|test match|wicket|batsman|bowler|basketball|nba\b|wnba|nfl\b|touchdown|quarterback|super bowl|rugby|six nations|golf|pga\b|ryder cup|formula\s?1|f1\b|grand prix|motogp|nascar|baseball|mlb\b|nhl\b|ice hockey|ufc\b|mma\b|boxing|heavyweight|darts|snooker|tour de france|kabaddi)\b/i;
  private static readonly FOOTBALL_RE =
    /\b(football|soccer|premier league|la ?liga|bundesliga|serie a|ligue 1|eredivisie|champions league|europa league|conference league|world cup|fifa|uefa|epl\b|mls\b|goalkeeper|midfielder|defender|striker|forward|free.?kick|offside|matchday|on loan|clean sheet|var\b|el clasico|derby)\b/i;

  private isFootball(
    title: string,
    summary: string | null,
    tags: string[],
    teamIds: string[],
  ): boolean {
    // A matched football team is the strongest possible signal.
    if (teamIds.length > 0) return true;
    const text = `${title}\n${summary ?? ''}\n${tags.join(' ')}`;
    const hasOther = RssAggregatorService.OTHER_SPORT_RE.test(text);
    if (!hasOther) return true; // no foreign-sport signal → assume football
    return RssAggregatorService.FOOTBALL_RE.test(text); // foreign signal — keep only if also football
  }

  @Interval('news-refresh', 600_000)
  async refresh() {
    if (this.running) return;
    this.running = true;
    let added = 0;
    try {
      // Refresh the team index before each pass — picks up teams seeded
      // after boot (e.g. running `seed:roster` post-deploy).
      await this.loadTeamMatchIndex().catch((e) =>
        this.log.warn(`team index load failed: ${(e as Error).message}`),
      );
      const results = await Promise.allSettled(this.feeds.map((f) => this.fetchFeed(f)));
      for (const r of results) {
        if (r.status === 'fulfilled') added += r.value;
        else this.log.warn(`feed failed: ${r.reason}`);
      }
      this.log.log(`news refresh: +${added} new across ${this.feeds.length} feeds`);
      // Sweep out any non-football articles already stored (e.g. from before
      // this filter existed, or a feed that's gone off-topic).
      await this.purgeNonFootball().catch((e) =>
        this.log.warn(`purge failed: ${(e as Error).message}`),
      );
    } finally {
      this.running = false;
    }
  }

  /// Delete already-stored articles that aren't football. Bounded to the most
  /// recent rows (the ones users actually see) and reuses [isFootball], so it
  /// stays DB-agnostic and consistent with the ingest gate.
  private async purgeNonFootball(): Promise<void> {
    const rows = await this.prisma.newsArticle.findMany({
      orderBy: { publishedAt: 'desc' },
      take: 500,
      select: { id: true, title: true, summary: true, tags: true, teamIds: true },
    });
    const drop = rows
      .filter((r) => !this.isFootball(r.title, r.summary, r.tags, r.teamIds))
      .map((r) => r.id);
    if (drop.length) {
      await this.prisma.newsArticle.deleteMany({ where: { id: { in: drop } } });
      this.log.log(`purged ${drop.length} non-football articles`);
    }
  }

  private async fetchFeed(url: string): Promise<number> {
    const feed = await this.parseFeed(url);
    const source = feed.title ?? new URL(url).hostname;
    let added = 0;

    for (const item of feed.items ?? []) {
      if (!item.link || !item.title) continue;
      const id = this.hash(item.link);
      const imageUrl = this.extractImage(item);
      const tags = this.extractTags(item);
      const title = item.title.trim();
      const summary = this.cleanSummary(item.contentSnippet ?? item.content ?? '');
      // Team-name detection on title + summary. Populates teamIds[] so the
      // "Following" tab actually returns articles about the user's teams.
      const teamIds = this.matchTeams(title, summary);

      // Skip non-football items (tennis/cricket/NBA/etc. from general feeds).
      if (!this.isFootball(title, summary, tags, teamIds)) continue;

      const created = await this.prisma.newsArticle.upsert({
        where: { id },
        create: {
          id,
          url: item.link,
          title,
          summary,
          source,
          imageUrl,
          publishedAt: item.isoDate ? new Date(item.isoDate) : new Date(),
          tags,
          teamIds,
        },
        // Backfill teamIds on existing rows when the match index changes
        // (e.g. you re-seed the roster and want articles re-tagged). Same
        // pattern + summary will produce the same set, so this is safe.
        update: { teamIds },
      });
      const isNew = created.fetchedAt.getTime() > Date.now() - 60_000;
      if (isNew) {
        added++;
        // Notify when the article qualifies. Freshness keeps volume sane:
        //   - breaking: tagged "breaking"/"live" upstream, AND
        //   - published in the last 30 min (not an old feed backfill).
        const tagsLower = tags.map((t) => t.toLowerCase());
        const looksBreaking = tagsLower.includes('breaking') || tagsLower.includes('live');
        const publishedRecently =
          created.publishedAt.getTime() > Date.now() - 30 * 60_000;
        const wantBreaking = looksBreaking && publishedRecently;
        const wantTeam = teamIds.length > 0 && publishedRecently;

        // Exactly-once notify across instances. The aggregator runs on every
        // server (no worker gate), so without this each instance would fire
        // the same pushes — that's the "3 notifications per article" bug. The
        // atomic flip of notifiedAt (null → now) is won by a single instance.
        if (wantBreaking || wantTeam) {
          const claim = await this.prisma.newsArticle.updateMany({
            where: { id, notifiedAt: null },
            data: { notifiedAt: new Date() },
          });
          if (claim.count === 1) {
            if (wantBreaking) {
              // Opt-in via subscription → every device on `news_breaking`
              // (Flutter gates the subscribe on the breakingNews preference).
              void this.push.pushToTopic(
                'news_breaking',
                { title: `⚡ ${source}`, body: item.title.trim().slice(0, 140) },
                {
                  type: 'news_breaking',
                  category: 'breakingNews',
                  articleId: id,
                  deepLink: `footballmojo://news/${id}`,
                },
              );
            }
            if (wantTeam) {
              // One push per tagged team topic (followers subscribe to
              // `team_{id}` on follow). teamIds is already de-duplicated.
              for (const teamId of teamIds) {
                void this.push.pushToTopic(
                  `team_${teamId}`,
                  { title: `📰 ${source}`, body: title.slice(0, 140) },
                  {
                    type: 'team_news',
                    category: 'breakingNews',
                    teamId,
                    articleId: id,
                    deepLink: `footballmojo://news/${id}`,
                  },
                );
              }
            }
          }
        }
      }
    }
    return added;
  }

  /// Robust feed fetch. Some publishers serve slightly-invalid XML (bare `&`,
  /// stray characters) that the strict SAX parser rejects ("Invalid character
  /// in entity name"). Fetch the raw body, lightly sanitize, then parse. Falls
  /// back to the parser's own URL fetch if our fetch fails.
  private async parseFeed(url: string) {
    try {
      const res = await fetch(url, {
        headers: { 'User-Agent': 'FootballMojo/1.0 (+https://pitch.footballmojo.in)' },
        signal: AbortSignal.timeout(20_000),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const raw = await res.text();
      return await this.parser.parseString(this.sanitizeXml(raw));
    } catch {
      return this.parser.parseURL(url);
    }
  }

  /// Escape bare ampersands that aren't part of a valid XML entity — the most
  /// common cause of feed parse failures. Leaves real entities (&amp; &#39;
  /// &#x2014;) untouched.
  private sanitizeXml(xml: string): string {
    return xml.replace(/&(?!(?:[a-zA-Z][a-zA-Z0-9]*|#\d+|#x[0-9a-fA-F]+);)/g, '&amp;');
  }

  private hash(input: string): string {
    return createHash('sha1').update(input).digest('hex').slice(0, 24);
  }

  private extractImage(item: Item): string | null {
    if (item.enclosure?.url) return item.enclosure.url;
    const media = (item as any)['media:content'];
    if (media?.$?.url) return media.$.url;
    const match = (item.content ?? '').match(/<img[^>]+src=["']([^"']+)["']/i);
    return match?.[1] ?? null;
  }

  private extractTags(item: Item): string[] {
    const cats = (item.categories ?? []).map((c) => (typeof c === 'string' ? c : (c as any)?._ ?? ''));
    return cats.filter(Boolean).slice(0, 8);
  }

  private cleanSummary(html: string): string {
    return html.replace(/<[^>]*>/g, '').replace(/\s+/g, ' ').trim().slice(0, 400);
  }
}
