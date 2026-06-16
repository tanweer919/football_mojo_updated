import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { PrismaService } from '../../common/prisma.service';
import { fixturePairKey } from './wc-team-aliases';

// FIFA's dedicated WC 2026 highlights playlist — every item is a match
// highlight, so it's a far cleaner + cheaper source than the channel's full
// uploads feed. Override via YOUTUBE_HIGHLIGHTS_PLAYLIST_ID if this changes or
// was copied incomplete (it's the `list=` value from the playlist URL).
const DEFAULT_HIGHLIGHTS_PLAYLIST = 'PLBRLtDhTHh5o';

interface YtVideo {
  id: string;
  title: string;
}

interface ParsedHighlight {
  teamA: string;
  teamB: string;
  scoreA: number;
  scoreB: number;
}

/**
 * Parse a FIFA-official highlight title into the two nations + scoreline.
 *
 * Canonical shape: `"Highlights | Canada 1-1 Bosnia and Herzegovina | FIFA World Cup 2026™"`.
 * We don't assume segment order beyond "there is a `Team N-N Team` scoreline
 * segment somewhere"; we just require the title to be a highlight of a World
 * Cup match. Returns null for anything that isn't a parseable WC highlight
 * (interviews, top-10s, other competitions, …).
 */
export function parseHighlightTitle(title: string): ParsedHighlight | null {
  if (!/highlight/i.test(title) || !/world cup/i.test(title)) return null;
  const segments = title.split('|').map((s) => s.trim());
  // The scoreline segment is the one shaped like "X <n>-<n> Y".
  const scoreRe = /^(.+?)\s+(\d+)\s*-\s*(\d+)\s+(.+)$/;
  for (const seg of segments) {
    const m = seg.match(scoreRe);
    if (m) {
      return {
        teamA: m[1].trim(),
        teamB: m[4].trim(),
        scoreA: Number(m[2]),
        scoreB: Number(m[3]),
      };
    }
  }
  return null;
}

/**
 * Primary highlight source: poll the FIFA-official YouTube channel and attach a
 * clip to each recently-finished match by matching the video title to the
 * fixture (team pair via the WC alias map + exact scoreline). Admins can still
 * set/override a link by hand — this only ever fills in matches whose
 * `highlightUrl` is still null, so a curated link is never clobbered.
 *
 * Cost-safe: zero upstream calls when nothing is pending; otherwise one cheap
 * `playlistItems` read of the channel's recent uploads per tick (~1 quota unit
 * per 50 videos, vs 100 for search). Worker-node only.
 *
 * Reads FIFA's dedicated highlights playlist by default (every item is a match
 * highlight); falls back to the channel's uploads only if no playlist is set.
 *
 * Config (Dokploy env, not repo):
 *   - YOUTUBE_API_KEY                required to enable auto-discovery
 *   - YOUTUBE_HIGHLIGHTS_PLAYLIST_ID preferred source; the `list=` id from the
 *                                    playlist URL. Defaults to the known WC one.
 *   - YOUTUBE_FIFA_HANDLE            default "fifa" (uploads fallback only)
 *   - YOUTUBE_FIFA_CHANNEL_ID        optional — pin uploads by channel id
 */
@Injectable()
export class HighlightsWorker {
  private readonly log = new Logger(HighlightsWorker.name);
  private readonly isWorker: boolean;
  private readonly apiKey?: string;
  private readonly handle: string;
  private readonly channelId?: string;
  private readonly highlightsPlaylistId: string;
  private resolvedPlaylistId?: string;

  constructor(
    cfg: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    this.isWorker =
      process.env.WORKER_MODE === 'true' ||
      cfg.get<string>('NODE_ENV') !== 'production';
    this.apiKey = cfg.get<string>('YOUTUBE_API_KEY') || undefined;
    this.handle = (cfg.get<string>('YOUTUBE_FIFA_HANDLE') || 'fifa').replace(/^@/, '');
    this.channelId = cfg.get<string>('YOUTUBE_FIFA_CHANNEL_ID') || undefined;
    this.highlightsPlaylistId =
      cfg.get<string>('YOUTUBE_HIGHLIGHTS_PLAYLIST_ID') || DEFAULT_HIGHLIGHTS_PLAYLIST;
  }

  @Cron(CronExpression.EVERY_30_MINUTES, { name: 'highlight-discover' })
  async tick(): Promise<void> {
    if (!this.isWorker) return;
    if (!this.apiKey) return; // feature disabled until a key is configured

    const now = Date.now();
    // Finished matches still missing a highlight. Highlights usually land within
    // hours; give 5 days of slack, then stop trying so we don't poll forever.
    const pending = await this.prisma.match.findMany({
      where: {
        status: 'FINISHED',
        highlightUrl: null,
        kickoffAt: { gte: new Date(now - 5 * 24 * 60 * 60_000) },
      },
      include: { homeTeam: true, awayTeam: true },
    });
    if (pending.length === 0) return; // nothing to match → no upstream call

    let videos: YtVideo[];
    try {
      videos = await this.fetchPlaylistVideos(200);
    } catch (e) {
      this.log.warn(`youtube fetch failed: ${(e as Error).message}`);
      return;
    }
    if (videos.length === 0) return;

    // Index parsed highlights by canonical team-pair. Uploads come newest-first,
    // so the first hit for a pair is the freshest clip.
    const byPair = new Map<string, ParsedHighlight & { videoId: string }>();
    for (const v of videos) {
      const parsed = parseHighlightTitle(v.title);
      if (!parsed) continue;
      const key = fixturePairKey(parsed.teamA, parsed.teamB);
      if (!byPair.has(key)) byPair.set(key, { ...parsed, videoId: v.id });
    }
    if (byPair.size === 0) return;

    let matched = 0;
    for (const m of pending) {
      const hit = byPair.get(fixturePairKey(m.homeTeam.name, m.awayTeam.name));
      if (!hit) continue;
      // Confirm it's the right clip: the scoreline must match (order-independent,
      // since we already know the fixture). Guards against a mis-parsed or
      // wrong-edition title sneaking onto a match.
      const a = [hit.scoreA, hit.scoreB].sort((x, y) => x - y);
      const b = [m.homeScore, m.awayScore].sort((x, y) => x - y);
      if (a[0] !== b[0] || a[1] !== b[1]) continue;

      const url = `https://www.youtube.com/watch?v=${hit.videoId}`;
      await this.prisma.match.update({ where: { id: m.id }, data: { highlightUrl: url } });
      matched++;
      this.log.log(
        `highlight matched: ${m.homeTeam.name} ${m.homeScore}-${m.awayScore} ${m.awayTeam.name} → ${hit.videoId}`,
      );
    }
    if (matched > 0) {
      this.log.log(`highlight discover: set ${matched}/${pending.length} pending match(es)`);
    }
  }

  /**
   * The playlist to read, cached for the process. Prefers the dedicated
   * highlights playlist; otherwise the channel's uploads (pinned by channel id,
   * or resolved from the @handle via one channels.list call).
   */
  private async resolvePlaylistId(): Promise<string | null> {
    if (this.resolvedPlaylistId) return this.resolvedPlaylistId;
    if (this.highlightsPlaylistId) {
      this.resolvedPlaylistId = this.highlightsPlaylistId;
      return this.resolvedPlaylistId;
    }
    if (this.channelId) {
      // Uploads playlist id is the channel id with the 'UC' prefix → 'UU'.
      this.resolvedPlaylistId = 'UU' + this.channelId.slice(2);
      return this.resolvedPlaylistId;
    }
    const url = new URL('https://www.googleapis.com/youtube/v3/channels');
    url.searchParams.set('part', 'contentDetails');
    url.searchParams.set('forHandle', this.handle);
    url.searchParams.set('key', this.apiKey!);
    const res = await fetch(url);
    if (!res.ok) throw new Error(`channels.list ${res.status}`);
    const json = (await res.json()) as {
      items?: Array<{ contentDetails?: { relatedPlaylists?: { uploads?: string } } }>;
    };
    const uploads = json.items?.[0]?.contentDetails?.relatedPlaylists?.uploads;
    if (uploads) this.resolvedPlaylistId = uploads;
    return uploads ?? null;
  }

  /** Up to `max` videos from the source playlist (paged, 50 at a time). */
  private async fetchPlaylistVideos(max: number): Promise<YtVideo[]> {
    const playlistId = await this.resolvePlaylistId();
    if (!playlistId) {
      this.log.warn('could not resolve a highlights/uploads playlist');
      return [];
    }
    const out: YtVideo[] = [];
    let pageToken: string | undefined;
    do {
      const url = new URL('https://www.googleapis.com/youtube/v3/playlistItems');
      url.searchParams.set('part', 'snippet');
      url.searchParams.set('playlistId', playlistId);
      url.searchParams.set('maxResults', '50');
      url.searchParams.set('key', this.apiKey!);
      if (pageToken) url.searchParams.set('pageToken', pageToken);
      const res = await fetch(url);
      if (!res.ok) throw new Error(`playlistItems ${res.status}`);
      const json = (await res.json()) as {
        nextPageToken?: string;
        items?: Array<{ snippet?: { title?: string; resourceId?: { videoId?: string } } }>;
      };
      for (const it of json.items ?? []) {
        const id = it.snippet?.resourceId?.videoId;
        const title = it.snippet?.title;
        if (id && title) out.push({ id, title });
      }
      pageToken = json.nextPageToken;
    } while (pageToken && out.length < max);
    return out;
  }
}
