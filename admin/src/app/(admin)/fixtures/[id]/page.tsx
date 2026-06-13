import { apiServer, BackendError } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { Panel, SectionHead } from '@/components/ui';
import Link from 'next/link';
import { notFound } from 'next/navigation';
import { WatchLinksEditor, type WatchLink } from './watch-links';

export const dynamic = 'force-dynamic';

interface FixtureDetail {
  id: string;
  kickoffAt: string;
  status: string;
  homeTeam: { name: string };
  awayTeam: { name: string };
  competition: { name: string } | null;
  watchLinks: WatchLink[];
}
interface Me { role: string; }

export default async function FixtureDetailPage({ params }: { params: { id: string } }) {
  let me: Me;
  let fx: FixtureDetail;
  try {
    [me, fx] = await Promise.all([
      apiServer<Me>('/admin/me'),
      apiServer<FixtureDetail>(`/admin/fixtures/${params.id}`),
    ]);
  } catch (e) {
    if (e instanceof BackendError && e.status === 404) notFound();
    throw e;
  }

  const title = `${fx.homeTeam.name} v ${fx.awayTeam.name}`;

  return (
    <>
      <Topbar title={title} role={me.role} />
      <div className="p-6 max-w-4xl space-y-5">
        <div className="text-sm text-fg-muted">
          <Link href="/fixtures" className="hover:text-gold">Fixtures</Link>
          <span className="mx-2 text-fg-muted2">/</span>
          <span className="text-fg-soft">{title}</span>
        </div>

        <Panel>
          <SectionHead eyebrow="Fixture" title={title} />
          <dl className="grid grid-cols-2 sm:grid-cols-4 gap-4 text-sm">
            <div><dt className="text-fg-muted2 text-xs">Competition</dt><dd className="text-fg">{fx.competition?.name ?? '—'}</dd></div>
            <div><dt className="text-fg-muted2 text-xs">Kickoff</dt><dd className="text-fg font-mono text-xs">{new Date(fx.kickoffAt).toLocaleString()}</dd></div>
            <div><dt className="text-fg-muted2 text-xs">Status</dt><dd className="text-fg">{fx.status}</dd></div>
            <div><dt className="text-fg-muted2 text-xs">Fixture ID</dt><dd className="text-fg font-mono text-xs">{fx.id}</dd></div>
          </dl>
        </Panel>

        <WatchLinksEditor matchId={fx.id} initial={fx.watchLinks} />
      </div>
    </>
  );
}
