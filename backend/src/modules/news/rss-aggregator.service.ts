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

  @Interval('news-refresh', 600_000)
  async refresh() {
    if (this.running) return;
    this.running = true;
    let added = 0;
    try {
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

      const created = await this.prisma.newsArticle.upsert({
        where: { id },
        create: {
          id,
          url: item.link,
          title: item.title.trim(),
          summary: this.cleanSummary(item.contentSnippet ?? item.content ?? ''),
          source,
          imageUrl,
          publishedAt: item.isoDate ? new Date(item.isoDate) : new Date(),
          tags,
        },
        update: {},
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
