import type { MetadataRoute } from 'next';
import { SITE } from '@/lib/site';
import { getUpcomingFixtures, getCompetitionFixtures } from '@/lib/api';
import { WC, GROUP_LETTERS, matchSlug } from '@/lib/wc';
import { LEAGUES } from '@/lib/leagues';
import { POSTS } from '@/lib/blog';

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const now = new Date();
  const u = (path: string) => `${SITE.url}${path}`;

  const [whereToWatch, wcFixtures] = await Promise.all([
    getUpcomingFixtures(21),
    getCompetitionFixtures(WC.competitionNameMatch, WC.startDate, WC.endDate),
  ]);

  // Dates within the tournament window that actually have ≥1 fixture.
  const wcDates = [...new Set(wcFixtures.map((f) => f.kickoffAt.slice(0, 10)))].sort();

  return [
    // Core
    { url: u('/'), lastModified: now, changeFrequency: 'weekly', priority: 1 },

    // World Cup hub (highest priority during the tournament)
    { url: u('/world-cup-2026'), lastModified: now, changeFrequency: 'hourly', priority: 0.95 },
    { url: u('/world-cup-2026/fixtures'), lastModified: now, changeFrequency: 'daily', priority: 0.9 },
    ...wcDates.map((d) => ({ url: u(`/world-cup-2026/fixtures/${d}`), lastModified: now, changeFrequency: 'daily' as const, priority: 0.7 })),
    ...GROUP_LETTERS.map((l) => ({ url: u(`/world-cup-2026/groups/${l.toLowerCase()}`), lastModified: now, changeFrequency: 'daily' as const, priority: 0.7 })),
    ...wcFixtures.map((f) => ({
      url: u(`/world-cup-2026/match/${matchSlug(f.homeTeam.name, f.awayTeam.name, f.kickoffAt)}`),
      lastModified: now, changeFrequency: 'daily' as const, priority: 0.6,
    })),

    // Evergreen leagues
    ...LEAGUES.map((l) => ({ url: u(`/leagues/${l.slug}`), lastModified: now, changeFrequency: 'daily' as const, priority: 0.7 })),

    // Editorial + blog
    { url: u('/best-football-score-apps'), lastModified: now, changeFrequency: 'weekly', priority: 0.6 },
    { url: u('/blog'), lastModified: now, changeFrequency: 'weekly', priority: 0.5 },
    ...POSTS.map((p) => ({ url: u(`/blog/${p.slug}`), lastModified: new Date(p.date), changeFrequency: 'monthly' as const, priority: 0.5 })),

    // Existing
    { url: u('/where-to-watch'), lastModified: now, changeFrequency: 'daily', priority: 0.8 },
    ...whereToWatch.map((f) => ({ url: u(`/where-to-watch/${f.id}`), lastModified: now, changeFrequency: 'daily' as const, priority: 0.5 })),
    { url: u('/privacy'), lastModified: now, changeFrequency: 'yearly', priority: 0.3 },
  ];
}
