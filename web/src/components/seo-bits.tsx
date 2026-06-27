import Link from 'next/link';
import { playUrl } from '@/lib/seo';

/** Inject a JSON-LD block. Pass any schema.org object. */
export function JsonLd({ data }: { data: unknown }) {
  return (
    <script
      type="application/ld+json"
      dangerouslySetInnerHTML={{ __html: JSON.stringify(data) }}
    />
  );
}

/** Visible + crawlable breadcrumb trail (pair with breadcrumbLd JSON-LD). */
export function Breadcrumbs({ items }: { items: Array<{ name: string; path: string }> }) {
  return (
    <nav aria-label="Breadcrumb" className="container-x pt-8">
      <ol className="flex flex-wrap items-center gap-2 text-xs text-fg-muted">
        {items.map((it, i) => (
          <li key={it.path} className="flex items-center gap-2">
            {i > 0 && <span className="text-fg-muted2">/</span>}
            {i < items.length - 1 ? (
              <Link href={it.path} className="transition hover:text-gold">{it.name}</Link>
            ) : (
              <span className="text-fg-soft">{it.name}</span>
            )}
          </li>
        ))}
      </ol>
    </nav>
  );
}

/**
 * Non-intrusive Play CTA band. `slug` drives the UTM so installs are
 * attributable to the page. Honest copy — value first, no dark patterns.
 */
export function PlayCta({ slug, headline, sub }: { slug: string; headline?: string; sub?: string }) {
  return (
    <section className="container-x my-16">
      <div className="panel flex flex-col items-start justify-between gap-6 p-8 sm:flex-row sm:items-center">
        <div className="max-w-xl">
          <h2 className="font-display text-2xl font-bold text-fg">
            {headline ?? 'Get live alerts in the app'}
          </h2>
          <p className="mt-2 text-sm leading-relaxed text-fg-muted">
            {sub ??
              'Instant goal, kick-off and full-time alerts, AI match previews & recaps, fixtures, tables and brackets — free, with no betting and no ads getting in the way.'}
          </p>
        </div>
        <a
          href={playUrl(slug)}
          target="_blank"
          rel="noopener"
          className="btn-gold shrink-0"
          aria-label="Get FootballMojo on Google Play"
        >
          Get it on Google Play
        </a>
      </div>
    </section>
  );
}
