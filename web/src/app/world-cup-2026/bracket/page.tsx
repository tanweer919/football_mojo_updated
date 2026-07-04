import type { Metadata } from 'next';
import type { Fixture } from '@/lib/api';
import { getCompetitionFixtures } from '@/lib/api';
import { WC, WC_R32, WC_FEED, normNation } from '@/lib/wc';
import { pageMeta, breadcrumbLd } from '@/lib/seo';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';
import { WcSubnav } from '@/components/wc-subnav';
import { BracketTree } from '@/components/bracket-tree';

export const revalidate = 120;
const PATH = '/world-cup-2026/bracket';
const FINISHED = new Set(['FINISHED', 'FT', 'AET', 'PEN']);

export const metadata: Metadata = pageMeta({
  title: 'World Cup 2026 Bracket — Knockout Tree',
  description:
    'The full FIFA World Cup 2026 knockout bracket — Round of 32 through the final. Teams advance automatically as results land. Free, no betting.',
  path: PATH,
});

/** Resolve each bracket slot (match number) to its fixture, propagating winners. */
function buildResolver(fixtures: Fixture[]) {
  const ko = fixtures.filter((f) => f.stage && !/group/i.test(f.stage));
  const key = (a: string, b: string) => [normNation(a), normNation(b)].sort().join('|');

  const fixtureByPair = new Map<string, Fixture>();
  for (const f of ko) fixtureByPair.set(key(f.homeTeam.name, f.awayTeam.name), f);

  const resultByPair = new Map<string, { w: string; l: string }>();
  for (const f of ko) {
    if (!FINISHED.has(f.status)) continue;
    const hn = normNation(f.homeTeam.name), an = normNation(f.awayTeam.name);
    let w = hn, l = an;
    if (f.homeScore < f.awayScore) { w = an; l = hn; }
    else if (f.homeScore === f.awayScore) {
      const hp = f.homePenalties ?? 0, ap = f.awayPenalties ?? 0;
      if (hp === ap) continue;
      if (hp < ap) { w = an; l = hn; }
    }
    resultByPair.set([hn, an].sort().join('|'), { w, l });
  }

  const teamsOf = new Map<number, [string, string]>();
  for (const [n, [h, a]] of Object.entries(WC_R32)) teamsOf.set(+n, [normNation(h), normNation(a)]);
  for (let n = 89; n <= 104; n++) {
    const feed = WC_FEED[n];
    if (!feed) continue;
    const res = (ref: string): string | undefined => {
      const tm = teamsOf.get(+ref.slice(1));
      if (!tm) return undefined;
      const r = resultByPair.get([tm[0], tm[1]].sort().join('|'));
      if (!r) return undefined;
      return ref[0] === 'W' ? r.w : r.l;
    };
    const h = res(feed[0]), a = res(feed[1]);
    if (h && a) teamsOf.set(n, [h, a]);
  }

  return (n: number): Fixture | null => {
    const tm = teamsOf.get(n);
    if (!tm) return null;
    return fixtureByPair.get([tm[0], tm[1]].sort().join('|')) ?? null;
  };
}

export default async function BracketPage() {
  const fixtures = await getCompetitionFixtures(WC.competitionNameMatch, '2026-06-28', WC.endDate);
  const resolver = buildResolver(fixtures);
  const anyResolved = fixtures.some((f) => f.stage && !/group/i.test(f.stage) && FINISHED.has(f.status));

  const crumbs = [
    { name: 'Home', path: '/' },
    { name: 'World Cup 2026', path: '/world-cup-2026' },
    { name: 'Bracket', path: PATH },
  ];

  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <WcSubnav />
      <Breadcrumbs items={crumbs} />

      <section className="container-x pt-8">
        <p className="eyebrow">FIFA World Cup 2026 · Knockouts</p>
        <h1 className="mt-3 font-display text-4xl font-extrabold tracking-tight sm:text-5xl">
          World Cup 2026 <span className="text-gold-grad">Bracket</span>
        </h1>
        <p className="mt-4 max-w-2xl text-base leading-relaxed text-fg-soft">
          The full knockout tree, split left and right toward the final in New York on 19 July.
          Winners advance automatically as each result comes in. Predict it in the app.
        </p>
        {!anyResolved && (
          <div className="mt-6 rounded-xl border border-gold/30 bg-gold/5 px-5 py-4 text-sm text-fg-soft">
            The Round of 32 is confirmed after the group stage ends on <strong>27 June</strong> — the
            bracket fills in automatically as ties are decided (knockouts begin <strong>28 June</strong>).
          </div>
        )}
        <p className="mt-3 text-xs text-fg-muted2 lg:hidden">← scroll to see the full bracket →</p>
      </section>

      <BracketTree resolver={resolver} />

      <PlayCta slug="world-cup-2026-bracket" headline="Predict the entire World Cup 2026 bracket" />
    </>
  );
}
