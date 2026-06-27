import type { Metadata } from 'next';
import Link from 'next/link';
import { pageMeta, breadcrumbLd } from '@/lib/seo';
import { POSTS } from '@/lib/blog';
import { Breadcrumbs, JsonLd } from '@/components/seo-bits';

export const revalidate = 86_400;
const PATH = '/blog';

export const metadata: Metadata = pageMeta({
  title: 'FootballMojo Blog — World Cup 2026 Guides',
  description:
    'Guides for the FIFA World Cup 2026 — how to watch, the schedule explained, groups & bracket guide, and the best halal, no-gambling football apps.',
  path: PATH,
});

export default function Blog() {
  const crumbs = [
    { name: 'Home', path: '/' },
    { name: 'Blog', path: PATH },
  ];
  const posts = [...POSTS].sort((a, b) => b.date.localeCompare(a.date));
  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <Breadcrumbs items={crumbs} />
      <section className="container-x pt-8">
        <p className="eyebrow">Guides &amp; explainers</p>
        <h1 className="mt-3 font-display text-4xl font-extrabold tracking-tight sm:text-5xl">
          FootballMojo <span className="text-gold-grad">Blog</span>
        </h1>
      </section>
      <div className="container-x mt-10 grid gap-4 sm:grid-cols-2">
        {posts.map((p) => (
          <Link key={p.slug} href={`/blog/${p.slug}`} className="panel p-6 transition hover:border-gold/40">
            <p className="text-xs text-fg-muted2">{longDate(p.date)}</p>
            <h2 className="mt-2 font-display text-lg font-bold text-fg">{p.title}</h2>
            <p className="mt-2 text-sm leading-relaxed text-fg-muted">{p.description}</p>
            <span className="mt-3 inline-block text-sm font-medium text-gold">Read →</span>
          </Link>
        ))}
      </div>
    </>
  );
}

function longDate(d: string): string {
  return new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(d));
}
