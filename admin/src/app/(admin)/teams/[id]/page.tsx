import { apiServer, BackendError } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { Panel, SectionHead, Badge } from '@/components/ui';
import { TeamEditForm } from './form';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';

export const dynamic = 'force-dynamic';

interface Me { role: string; }
interface TeamDetail {
  id: string;
  name: string;
  shortName: string;
  countryCode: string | null;
  crestUrl: string | null;
  primaryColor: string | null;
  competition: { id: string; name: string } | null;
  _count: { players: number; homeMatches: number; awayMatches: number };
}

export default async function TeamDetailPage({ params }: { params: { id: string } }) {
  let me: Me;
  let team: TeamDetail;
  try {
    [me, team] = await Promise.all([
      apiServer<Me>('/admin/me'),
      apiServer<TeamDetail>(`/admin/teams/${params.id}`),
    ]);
  } catch (e) {
    if (e instanceof BackendError && e.status === 404) notFound();
    throw e;
  }

  return (
    <>
      <Topbar title={team.name} role={me.role} />
      <div className="p-6 max-w-5xl">
        <div className="flex items-center gap-2 text-xs text-fg-muted mb-4">
          <Link href="/teams" className="hover:text-gold">Teams</Link>
          <span>/</span>
          <span className="text-fg-soft font-mono">{team.id}</span>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-[1fr_280px] gap-6">
          <TeamEditForm
            team={{
              id: team.id,
              name: team.name,
              shortName: team.shortName,
              countryCode: team.countryCode ?? '',
              crestUrl: team.crestUrl ?? '',
              primaryColor: team.primaryColor ?? '',
            }}
          />

          <aside className="space-y-4">
            <div className="eyebrow-gold">Preview</div>
            <Panel className="!p-5 text-center">
              {team.crestUrl ? (
                <div className="w-24 h-24 mx-auto mb-3 bg-surface-2 rounded-md flex items-center justify-center">
                  <Image src={team.crestUrl} alt="" width={80} height={80} className="object-contain" unoptimized />
                </div>
              ) : (
                <div className="w-24 h-24 mx-auto mb-3 bg-surface-2 rounded-md flex items-center justify-center text-fg-muted2 text-3xl">∅</div>
              )}
              <div className="font-bold tracking-tight">{team.name}</div>
              <div className="text-xs font-mono text-fg-muted mt-1">{team.shortName}</div>
              {team.countryCode && <Badge className="mt-3" tone="gold">{team.countryCode}</Badge>}
            </Panel>

            <Panel className="!p-4">
              <SectionHead eyebrow="Stats" title="Linked rows" />
              <div className="space-y-2 text-xs">
                <Row label="Competition">
                  <span className="text-fg-soft">{team.competition?.name ?? '—'}</span>
                </Row>
                <Row label="Players">
                  <Link href={`/players?q=${encodeURIComponent(team.name)}`} className="text-gold hover:underline font-mono">
                    {team._count.players}
                  </Link>
                </Row>
                <Row label="Matches">
                  <span className="font-mono text-fg-soft">{team._count.homeMatches + team._count.awayMatches}</span>
                </Row>
              </div>
            </Panel>
          </aside>
        </div>
      </div>
    </>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center justify-between">
      <span className="eyebrow !text-[8px]">{label}</span>
      {children}
    </div>
  );
}
