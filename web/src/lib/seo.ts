import type { Metadata } from 'next';
import { SITE } from '@/lib/site';

/**
 * Locales we localize for (mirrors the 13-locale Play Store listing). Pass 1
 * ships English at root paths; locale routes are added in pass 2 with
 * human-reviewed translations, at which point `hreflangFor` starts emitting
 * per-locale alternates. Until then we emit x-default → the English page so we
 * never point hreflang at pages that don't exist yet (which would hurt ranking).
 */
export const LOCALES = [
  'en', 'en-GB', 'en-IN', 'fr', 'fr-CA', 'de', 'it',
  'pt-BR', 'pt-PT', 'es', 'es-419', 'es-ES', 'ar',
] as const;
export type Locale = (typeof LOCALES)[number];

/** Play Store URL with campaign UTM so installs are attributable per page. */
export function playUrl(pageSlug: string): string {
  const u = new URL(SITE.playStoreUrl);
  u.searchParams.set('utm_source', 'web');
  u.searchParams.set('utm_medium', 'organic');
  u.searchParams.set('utm_campaign', 'worldcup2026');
  u.searchParams.set('utm_content', pageSlug);
  return u.toString();
}

/** hreflang alternates for a path. Pass 1: canonical + x-default only. */
function hreflangFor(path: string): Metadata['alternates'] {
  return {
    canonical: path,
    languages: {
      // x-default + en both resolve to the English page for now.
      'x-default': path,
      en: path,
    },
  };
}

interface PageMetaInput {
  title: string;          // ≤60 chars, no brand suffix (template adds it)
  description: string;    // ≤155 chars
  path: string;           // e.g. '/world-cup-2026'
  index?: boolean;        // default true; false → noindex (thin/coming-soon)
  ogTitle?: string;
}

/** Standard page metadata: unique title/description, canonical, hreflang, OG. */
export function pageMeta({ title, description, path, index = true, ogTitle }: PageMetaInput): Metadata {
  return {
    title,
    description,
    alternates: hreflangFor(path),
    robots: index
      ? { index: true, follow: true, googleBot: { index: true, follow: true, 'max-image-preview': 'large', 'max-snippet': -1 } }
      : { index: false, follow: true },
    openGraph: {
      type: 'website',
      siteName: SITE.name,
      url: `${SITE.url}${path}`,
      title: ogTitle ?? `${title} · ${SITE.name}`,
      description,
      // Each route's opengraph-image.tsx (or the root one) supplies the image.
    },
    twitter: { card: 'summary_large_image', title: ogTitle ?? title, description },
  };
}

// ── JSON-LD builders ─────────────────────────────────────────────────────────

export function breadcrumbLd(items: Array<{ name: string; path: string }>) {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((it, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: it.name,
      item: `${SITE.url}${it.path}`,
    })),
  };
}

export function sportsEventLd(input: {
  home: string; away: string; startDate: string; venue?: string | null; city?: string | null; path: string;
}) {
  return {
    '@context': 'https://schema.org',
    '@type': 'SportsEvent',
    name: `${input.home} vs ${input.away} — FIFA World Cup 2026`,
    startDate: input.startDate,
    sport: 'Soccer',
    url: `${SITE.url}${input.path}`,
    ...(input.venue
      ? { location: { '@type': 'Place', name: input.venue, ...(input.city ? { address: input.city } : {}) } }
      : {}),
    competitor: [
      { '@type': 'SportsTeam', name: input.home },
      { '@type': 'SportsTeam', name: input.away },
    ],
    organizer: { '@type': 'Organization', name: 'FIFA' },
  };
}

export function faqLd(qas: Array<{ q: string; a: string }>) {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: qas.map((qa) => ({
      '@type': 'Question',
      name: qa.q,
      acceptedAnswer: { '@type': 'Answer', text: qa.a },
    })),
  };
}

/** The app card — reused on app-CTA pages. aggregateRating intentionally omitted (never fake). */
export function appLd() {
  return {
    '@context': 'https://schema.org',
    '@type': 'MobileApplication',
    name: SITE.name,
    operatingSystem: 'ANDROID',
    applicationCategory: 'SportsApplication',
    url: SITE.url,
    downloadUrl: SITE.playStoreUrl,
    installUrl: SITE.playStoreUrl,
    offers: { '@type': 'Offer', price: '0', priceCurrency: 'USD' },
    // aggregateRating: TODO — wire real Play rating; never hardcode a fake one.
  };
}
