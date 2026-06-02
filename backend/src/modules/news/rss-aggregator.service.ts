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
    } finally {
      this.running = false;
    }
  }

  private async fetchFeed(url: string): Promise<number> {
    const feed = await this.parser.parseURL(url);
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
        // Push as breaking when the article qualifies. Two signals:
        //   1. Tagged "breaking" or "live" upstream.
        //   2. Published in the last 30 minutes (genuinely fresh — not a
        //      backfill from an old feed).
        // Both keep notification volume sane while still catching the
        // moments that matter (transfers, injury news, match incidents).
        const tagsLower = tags.map((t) => t.toLowerCase());
        const looksBreaking = tagsLower.includes('breaking') || tagsLower.includes('live');
        const publishedRecently =
          created.publishedAt.getTime() > Date.now() - 30 * 60_000;
        if (looksBreaking && publishedRecently) {
          // Topic broadcast — opt-in via subscription, so this fires to
          // every device that subscribed to `news_breaking` (Flutter side
          // gates the subscription on the breakingNews preference).
          void this.push.pushToTopic(
            'news_breaking',
            {
              title: `⚡ ${source}`,
              body: item.title.trim().slice(0, 140),
            },
            {
              type: 'news_breaking',
              articleId: id,
              deepLink: `footballmojo://news/${id}`,
            },
          );
        }
      }
    }
    return added;
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
