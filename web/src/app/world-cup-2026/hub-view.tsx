import Link from 'next/link';
import { breadcrumbLd, faqLd, appLd } from '@/lib/seo';
import { getGroups, getCompetitionFixtures } from '@/lib/api';
import { WC, WC_PHASES, HOST_CITIES } from '@/lib/wc';
import { type Dict, type Locale, isRtl } from '@/lib/i18n';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';
import { FixtureList, GroupTable, ComingSoon } from '@/components/match-bits';

/**
 * The World Cup 2026 hub, rendered from a localized `dict`. Used by the English
 * route (`/world-cup-2026`) and every `/[locale]/world-cup-2026` route.
 */
export async function HubView({ dict, locale }: { dict: Dict; locale: Locale }) {
  const hubPath = locale === 'en' ? '/world-cup-2026' : `/${locale}/world-cup-2026`;

  const today = new Date();
  const from = new Date(today.getTime() - 3 * 86_400_000).toISOString().slice(0, 10);
  const to = new Date(today.getTime() + 12 * 86_400_000).toISOString().slice(0, 10);

  const [groups, fixtures] = await Promise.all([
    getGroups(WC.competitionId),
    getCompetitionFixtures(WC.competitionNameMatch, from, to),
  ]);

  const isKnockout = (s?: string | null) => !!s && !/^GROUP/i.test(s);
  const upcoming = fixtures.filter((f) => f.status === 'SCHEDULED').slice(0, 8);
  const recent = fixtures.filter((f) => ['FINISHED', 'FT', 'AET', 'PEN'].includes(f.status)).slice(-6).reverse();
  const knockout = fixtures.filter((f) => isKnockout(f.stage)).slice(0, 16);

  const crumbs = [
    { name: 'Home', path: locale === 'en' ? '/' : `/${locale}` },
    { name: dict.h1a, path: hubPath },
  ];

  return (
    <div lang={locale} dir={isRtl(locale) ? 'rtl' : 'ltr'}>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <JsonLd data={faqLd(dict.faqs)} />
      <JsonLd data={appLd()} />
      <Breadcrumbs items={crumbs} />

      <section className="container-x pt-8">
        <p className="eyebrow">{dict.heroKicker}</p>
        <h1 className="mt-3 font-display text-4xl font-extrabold leading-tight tracking-tight sm:text-5xl">
          {dict.h1a} <span className="text-gold-grad">{dict.h1b}</span>
        </h1>
        <p className="mt-4 max-w-2xl text-base leading-relaxed text-fg-soft">{dict.intro}</p>
      </section>

      <section className="container-x mt-12">
        <div className="mb-4 flex items-end justify-between">
          <h2 className="font-display text-2xl font-bold">{dict.fixturesHeading}</h2>
          <Link href="/world-cup-2026/fixtures" className="text-sm font-medium text-gold transition hover:text-gold-soft">
            {dict.allFixtures}
          </Link>
        </div>
        {recent.length > 0 && (<><h3 className="eyebrow mb-3 !text-fg-muted">{dict.latestResults}</h3><FixtureList fixtures={recent} /></>)}
        {upcoming.length > 0 && (<><h3 className="eyebrow mb-3 mt-8 !text-fg-muted">{dict.upcoming}</h3><FixtureList fixtures={upcoming} /></>)}
        {recent.length === 0 && upcoming.length === 0 && (
          <ComingSoon title={dict.fixturesHeading} note={dict.bracketSoonNote} />
        )}
      </section>

      <section className="container-x mt-16">
        <h2 className="mb-4 font-display text-2xl font-bold">{dict.standingsHeading}</h2>
        {groups.length > 0 ? (
          <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            {groups.map((g) => <GroupTable key={g.id} group={g} />)}
          </div>
        ) : (
          <ComingSoon title={dict.standingsHeading} note={dict.bracketSoonNote} />
        )}
      </section>

      <section className="container-x mt-16">
        <h2 className="mb-4 font-display text-2xl font-bold">{dict.bracketHeading}</h2>
        {knockout.length > 0 ? (
          <FixtureList fixtures={knockout} />
        ) : (
          <ComingSoon title={dict.bracketSoonTitle} note={dict.bracketSoonNote} />
        )}
      </section>

      <section className="container-x mt-16">
        <h2 className="mb-4 font-display text-2xl font-bold">{dict.formatHeading}</h2>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {WC_PHASES.map((p) => (
            <div key={p.key} className="panel p-5">
              <h3 className="font-display text-base font-bold text-fg">{p.label}</h3>
              <p className="mt-1 text-sm text-fg-muted">{fmtRange(p.from, p.to)}</p>
              <p className="mt-2 text-xs text-fg-muted2">{p.matches} matches</p>
            </div>
          ))}
        </div>
      </section>

      <section className="container-x mt-16">
        <h2 className="mb-4 font-display text-2xl font-bold">{dict.hostsHeading}</h2>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
          {HOST_CITIES.map((h) => (
            <div key={h.stadium} className="panel p-4">
              <p className="text-sm font-bold text-fg">{h.city}</p>
              <p className="mt-0.5 text-xs text-fg-soft">{h.stadium}</p>
              <p className="mt-1 text-[11px] text-fg-muted2">{h.country}</p>
            </div>
          ))}
        </div>
      </section>

      <PlayCta slug={`world-cup-2026-${locale}`} headline={dict.ctaHeadline} />

      <section className="container-x my-16">
        <h2 className="mb-4 font-display text-2xl font-bold">{dict.faqHeading}</h2>
        <div className="space-y-3">
          {dict.faqs.map((f) => (
            <details key={f.q} className="panel p-5">
              <summary className="cursor-pointer text-base font-semibold text-fg">{f.q}</summary>
              <p className="mt-2 text-sm leading-relaxed text-fg-muted">{f.a}</p>
            </details>
          ))}
        </div>
      </section>
    </div>
  );
}

function fmtRange(from: string, to: string): string {
  const opt: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short', timeZone: 'UTC' };
  const fmt = (d: string) => new Intl.DateTimeFormat('en-GB', opt).format(new Date(d));
  return from === to ? fmt(from) : `${fmt(from)} – ${fmt(to)}`;
}
