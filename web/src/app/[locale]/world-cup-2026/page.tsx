import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { pageMeta } from '@/lib/seo';
import { getDict, NON_DEFAULT_LOCALES, LOCALES, type Locale } from '@/lib/i18n';
import { HubView } from '../../world-cup-2026/hub-view';

export const revalidate = 120;
export const dynamicParams = false;

/** English lives at the root /world-cup-2026; this handles the other locales. */
export function generateStaticParams() {
  return NON_DEFAULT_LOCALES.map((locale) => ({ locale }));
}

function asLocale(l: string): Locale | null {
  return (LOCALES as readonly string[]).includes(l) ? (l as Locale) : null;
}

export async function generateMetadata({ params }: { params: { locale: string } }): Promise<Metadata> {
  const locale = asLocale(params.locale);
  if (!locale || locale === 'en') return {};
  const dict = getDict(locale);
  return pageMeta({
    title: dict.title,
    description: dict.description,
    ogTitle: dict.ogTitle,
    path: '/world-cup-2026',
    locale,
    localized: true,
  });
}

export default function LocalizedHub({ params }: { params: { locale: string } }) {
  const locale = asLocale(params.locale);
  if (!locale || locale === 'en') notFound();
  return <HubView dict={getDict(locale)} locale={locale} />;
}
