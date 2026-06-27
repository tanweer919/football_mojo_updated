import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import { pageMeta, breadcrumbLd } from '@/lib/seo';
import { POSTS, postBySlug } from '@/lib/blog';
import { SITE } from '@/lib/site';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';

export const revalidate = 86_400;
export const dynamicParams = false;

export function generateStaticParams() {
  return POSTS.map((p) => ({ slug: p.slug }));
}

export async function generateMetadata({ params }: { params: { slug: string } }): Promise<Metadata> {
  const p = postBySlug(params.slug);
  if (!p) return pageMeta({ title: 'Blog', description: 'FootballMojo blog.', path: `/blog/${params.slug}`, index: false });
  return pageMeta({ title: p.title, description: p.description, path: `/blog/${p.slug}` });
}

export default function BlogPost({ params }: { params: { slug: string } }) {
  const p = postBySlug(params.slug);
  if (!p) notFound();

  const crumbs = [
    { name: 'Home', path: '/' },
    { name: 'Blog', path: '/blog' },
    { name: p.title, path: `/blog/${p.slug}` },
  ];

  const articleLd = {
    '@context': 'https://schema.org',
    '@type': 'Article',
    headline: p.title,
    description: p.description,
    datePublished: p.date,
    dateModified: p.date,
    author: { '@type': 'Organization', name: SITE.name },
    publisher: { '@type': 'Organization', name: SITE.name, logo: { '@type': 'ImageObject', url: `${SITE.url}/logo.png` } },
    mainEntityOfPage: `${SITE.url}/blog/${p.slug}`,
  };

  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <JsonLd data={articleLd} />
      <Breadcrumbs items={crumbs} />
      <article className="container-x max-w-3xl pt-8">
        <p className="text-xs text-fg-muted2">{longDate(p.date)}</p>
        <h1 className="mt-2 font-display text-3xl font-extrabold tracking-tight sm:text-4xl">{p.title}</h1>
        <div className="mt-6 space-y-4">
          {p.body.map((b, i) => {
            if (b.t === 'h2') return <h2 key={i} className="pt-2 font-display text-xl font-bold text-fg">{b.text}</h2>;
            if (b.t === 'ul') return (
              <ul key={i} className="list-disc space-y-1.5 pl-5 text-fg-soft">
                {b.items.map((it, j) => <li key={j} className="leading-relaxed">{it}</li>)}
              </ul>
            );
            return <p key={i} className="leading-relaxed text-fg-soft">{b.text}</p>;
          })}
        </div>
        <p className="mt-8 text-sm text-fg-muted">
          More: <Link href="/world-cup-2026" className="text-gold hover:text-gold-soft">World Cup 2026 hub</Link>
        </p>
      </article>
      <PlayCta slug={`blog-${p.slug}`} />
    </>
  );
}

function longDate(d: string): string {
  return new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(d));
}
