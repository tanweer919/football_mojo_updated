import type { Metadata } from 'next';
import { pageMeta } from '@/lib/seo';
import { getDict } from '@/lib/i18n';
import { HubView } from './hub-view';

export const revalidate = 600;

const dict = getDict('en');

export const metadata: Metadata = pageMeta({
  title: dict.title,
  description: dict.description,
  ogTitle: dict.ogTitle,
  path: '/world-cup-2026',
  locale: 'en',
  localized: true, // this route has /[locale]/world-cup-2026 variants → full hreflang
});

export default function WorldCup2026Hub() {
  return <HubView dict={dict} locale="en" />;
}
