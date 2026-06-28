import type { Metadata } from 'next';
import { pageMeta, breadcrumbLd } from '@/lib/seo';
import { getGroups, getCompetitionFixtures } from '@/lib/api';
import { WC, GROUP_LETTERS } from '@/lib/wc';
import { Breadcrumbs, JsonLd, PlayCta } from '@/components/seo-bits';
import { GroupTable, FixtureList, ComingSoon } from '@/components/match-bits';
import { WcSubnav } from '@/components/wc-subnav';

export const revalidate = 300;
export const dynamicParams = false;

export function generateStaticParams() {
  return GROUP_LETTERS.map((l) => ({ group: l.toLowerCase() }));
}

export async function generateMetadata({ params }: { params: { group: string } }): Promise<Metadata> {
  const L = params.group.toUpperCase();
  return pageMeta({
    title: `World Cup 2026 Group ${L} — Table & Fixtures`,
    description: `FIFA World Cup 2026 Group ${L}: live standings, fixtures and results. See who tops the group and who qualifies. Free, no betting.`,
    path: `/world-cup-2026/groups/${params.group}`,
  });
}

export default async function WcGroup({ params }: { params: { group: string } }) {
  const letter = params.group.toUpperCase();
  const [groups, fixtures] = await Promise.all([
    getGroups(WC.competitionId),
    getCompetitionFixtures(WC.competitionNameMatch, WC.startDate, '2026-06-27'),
  ]);
  const group = groups.find((g) => g.letter.toUpperCase() === letter);

  const crumbs = [
    { name: 'Home', path: '/' },
    { name: 'World Cup 2026', path: '/world-cup-2026' },
    { name: `Group ${letter}`, path: `/world-cup-2026/groups/${params.group}` },
  ];

  const teamIds = new Set(group?.standings.map((s) => s.team.id) ?? []);
  const groupFixtures = fixtures.filter((f) => teamIds.has(f.homeTeam.id) && teamIds.has(f.awayTeam.id));

  return (
    <>
      <JsonLd data={breadcrumbLd(crumbs)} />
      <WcSubnav />
      <Breadcrumbs items={crumbs} />
      <section className="container-x pt-8">
        <p className="eyebrow">FIFA World Cup 2026</p>
        <h1 className="mt-3 font-display text-4xl font-extrabold tracking-tight sm:text-5xl">
          World Cup 2026 <span className="text-gold-grad">Group {letter}</span>
        </h1>
        <p className="mt-4 max-w-2xl text-base leading-relaxed text-fg-soft">
          Live Group {letter} standings, fixtures and results from the FIFA World Cup 2026 group stage.
          The top two teams plus the best third-placed sides advance to the Round of 32.
        </p>
      </section>

      <div className="container-x mt-10 space-y-10">
        {group ? (
          <GroupTable group={group} />
        ) : (
          <ComingSoon title={`Group ${letter} table loads at kick-off`} note="Standings appear here automatically once the group stage begins." />
        )}
        {groupFixtures.length > 0 && (
          <section>
            <h2 className="mb-3 font-display text-xl font-bold">Group {letter} fixtures &amp; results</h2>
            <FixtureList fixtures={groupFixtures} />
          </section>
        )}
      </div>

      <PlayCta slug={`world-cup-2026-group-${params.group}`} />
    </>
  );
}
