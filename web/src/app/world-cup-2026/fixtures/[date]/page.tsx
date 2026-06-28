import type { Metadata } from 'next';
import { pageMeta, breadcrumbLd } from '@/lib/seo';
import { getCompetitionFixtures } from '@/lib/api';
import { WC } from '@/lib/wc';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';
import { FixtureList, ComingSoon } from '@/components/match-bits';

export const revalidate = 600;
export const dynamicParams = true; // allow any in-window date; out-of-window → noindex

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

/** Pre-render every date in the tournament window. */
export function generateStaticParams() {
  const out: { date: string }[] = [];
  for (let t = Date.parse(WC.startDate); t <= Date.parse(WC.endDate); t += 86_400_000) {
    out.push({ date: new Date(t).toISOString().slice(0, 10) });
  }
  return out;
}

function inWindow(date: string): boolean {
  return DATE_RE.test(date) && date >= WC.startDate && date <= WC.endDate;
}

export async function generateMetadata({ params }: { params: { date: string } }): Promise<Metadata> {
  const valid = inWindow(params.date);
  return pageMeta({
    title: valid ? `World Cup 2026 Fixtures — ${shortDate(params.date)}` : 'World Cup 2026 Fixtures',
    description: valid
      ? `All FIFA World Cup 2026 matches on ${longDate(params.date)} — kick-off times in your timezone, live scores and results. Free, no betting.`
      : 'FIFA World Cup 2026 fixtures by date.',
    path: `/world-cup-2026/fixtures/${params.date}`,
    index: valid,
  });
}

export default async function WcFixturesByDate({ params }: { params: { date: string } }) {
  const valid = inWindow(params.date);
  const crumbs = [
    { name: 'Home', path: '/' },
    { name: 'World Cup 2026', path: '/world-cup-2026' },
    { name: 'Fixtures', path: '/world-cup-2026/fixtures' },
    { name: valid ? shortDate(params.date) : 'Date', path: `/world-cup-2026/fixtures/${params.date}` },
  ];

  if (!valid) {
    return (
      <>
        <Breadcrumbs items={crumbs} />
        <ComingSoon title="No matches on this date" note="That date is outside the World Cup 2026 window (11 June – 19 July 2026). Browse the full fixtures list instead." />
      </>
    );
  }

  const all = await getCompetitionFixtures(WC.competitionNameMatch, params.date, params.date);

  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <Breadcrumbs items={crumbs} />
      <section className="container-x pt-8">
        <p className="eyebrow">FIFA World Cup 2026</p>
        <h1 className="mt-3 font-display text-3xl font-extrabold tracking-tight sm:text-4xl">
          World Cup 2026 Fixtures — <span className="text-gold-grad">{longDate(params.date)}</span>
        </h1>
      </section>
      <div className="container-x mt-8">
        {all.length > 0 ? (
          <FixtureList fixtures={all} />
        ) : (
          <ComingSoon title="No matches scheduled (yet) for this day" note="Fixtures appear here automatically as the schedule is confirmed." />
        )}
      </div>
      <PlayCta slug="world-cup-2026-fixtures-date" />
    </>
  );
}

function shortDate(d: string): string {
  return new Intl.DateTimeFormat('en-GB', { day: 'numeric', month: 'short', timeZone: 'UTC' }).format(new Date(d));
}
function longDate(d: string): string {
  return new Intl.DateTimeFormat('en-GB', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' }).format(new Date(d));
}
