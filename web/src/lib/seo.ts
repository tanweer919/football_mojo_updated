import type { Metadata } from 'next';
import { SITE } from '@/lib/site';
import { LOCALES, NON_DEFAULT_LOCALES, DEFAULT_LOCALE, type Locale } from '@/lib/i18n';

export { LOCALES };
export type { Locale };

/**
 * Play Store URL with **install-referrer** attribution. Google Play only
 * captures the single `referrer` param (URL-encoded) into the Install Referrer
 * API / Play Console acquisition reports — loose `utm_*` query params on the
 * Play URL are ignored. So we pack the UTM into `referrer`. `pageSlug` lets you
 * see which page drove the install.
 */
export function playUrl(pageSlug = 'site'): string {
  const u = new URL(SITE.playStoreUrl);
  const referrer = new URLSearchParams({
    utm_source: SITE.domain,        // footballmojo.in
    utm_medium: 'web',
    utm_campaign: 'worldcup2026',
    utm_content: pageSlug,
  }).toString();
  u.searchParams.set('referrer', referrer); // URLSearchParams encodes the value
  return u.toString();
}

/**
 * hreflang alternates. `basePath` is the locale-less path (e.g. '/world-cup-2026').
 * - English lives at the root path; other locales at `/{locale}{basePath}`.
 * - `localized` pages (those that actually have locale routes) emit a full
 *   per-locale alternate set; everything else emits only x-default + en so we
 *   never point hreflang at a route that doesn't exist.
 */
function hreflangFor(basePath: string, locale: Locale, localized: boolean): Metadata['alternates'] {
  const canonical = locale === DEFAULT_LOCALE ? basePath : `/${locale}${basePath}`;
  const languages: Record<string, string> = { 'x-default': basePath, en: basePath };
  if (localized) for (const l of NON_DEFAULT_LOCALES) languages[l] = `/${l}${basePath}`;
  return { canonical, languages };
}

interface PageMetaInput {
  title: string;          // ≤60 chars, no brand suffix (template adds it)
  description: string;    // ≤155 chars
  path: string;           // locale-LESS base path, e.g. '/world-cup-2026'
  index?: boolean;        // default true; false → noindex (thin/coming-soon)
  ogTitle?: string;
  locale?: Locale;        // default 'en' (root); set for /[locale]/… pages
  localized?: boolean;    // true → this route has locale variants (emit all hreflang)
}

/** Standard page metadata: unique title/description, canonical, hreflang, OG. */
export function pageMeta({ title, description, path, index = true, ogTitle, locale = DEFAULT_LOCALE, localized = false }: PageMetaInput): Metadata {
  const url = locale === DEFAULT_LOCALE ? `${SITE.url}${path}` : `${SITE.url}/${locale}${path}`;
  return {
    title,
    description,
    alternates: hreflangFor(path, locale, localized),
    robots: index
      ? { index: true, follow: true, googleBot: { index: true, follow: true, 'max-image-preview': 'large', 'max-snippet': -1 } }
      : { index: false, follow: true },
    openGraph: {
      type: 'website',
      siteName: SITE.name,
      url,
      title: ogTitle ?? `${title} · ${SITE.name}`,
      description,
      locale: locale.replace('-', '_'),
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

/** The whole tournament as a SportsEvent — for the hub. */
export function tournamentLd() {
  return {
    '@context': 'https://schema.org',
    '@type': 'SportsEvent',
    name: 'FIFA World Cup 2026',
    sport: 'Soccer',
    startDate: '2026-06-11',
    endDate: '2026-07-19',
    url: `${SITE.url}/world-cup-2026`,
    organizer: { '@type': 'Organization', name: 'FIFA' },
    location: [
      { '@type': 'Country', name: 'United States' },
      { '@type': 'Country', name: 'Canada' },
      { '@type': 'Country', name: 'Mexico' },
    ],
    description: 'The 2026 FIFA World Cup — 48 teams, 104 matches, hosted across the USA, Canada and Mexico.',
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
