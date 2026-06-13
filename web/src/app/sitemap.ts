import type { MetadataRoute } from 'next';
import { SITE } from '@/lib/site';
import { getUpcomingFixtures } from '@/lib/api';

export const revalidate = 3600;

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const now = new Date();
  const fixtures = await getUpcomingFixtures(21);
  return [
    { url: `${SITE.url}/`, lastModified: now, changeFrequency: 'weekly', priority: 1 },
    { url: `${SITE.url}/where-to-watch`, lastModified: now, changeFrequency: 'daily', priority: 0.8 },
    ...fixtures.map((f) => ({
      url: `${SITE.url}/where-to-watch/${f.id}`,
      lastModified: now,
      changeFrequency: 'daily' as const,
      priority: 0.6,
    })),
    { url: `${SITE.url}/privacy`, lastModified: now, changeFrequency: 'yearly', priority: 0.5 },
  ];
}
