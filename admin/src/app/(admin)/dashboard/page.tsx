import { apiServer } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { Panel, Badge } from '@/components/ui';
import Link from 'next/link';

export const dynamic = 'force-dynamic';

interface Stats {
  playersTotal: number;
  playersWithPhoto: number;
  playersWithCutout: number;
  cardsTotal: number;
  cardsMinted: number;
  usersTotal: number;
  admins: number;
  teamsTotal: number;
  competitionsTotal: number;
  matchesTotal: number;
}
interface Me { id: string; role: string; email: string | null; displayName: string | null; }

export default async function DashboardPage() {
  // Two backend calls in parallel — `me` for the topbar role badge, `stats`
  // for the panel below. Server-rendered so the numbers are fresh on each
  // visit (no client hydration cost).
  const [me, stats] = await Promise.all([
    apiServer<Me>('/admin/me'),
    apiServer<Stats>('/admin/stats'),
  ]);

  const photoCoverage = stats.playersTotal === 0 ? 0 : Math.round((stats.playersWithPhoto / stats.playersTotal) * 100);
  const cutoutCoverage = stats.playersTotal === 0 ? 0 : Math.round((stats.playersWithCutout / stats.playersTotal) * 100);

  return (
    <>
      <Topbar title="Dashboard" role={me.role} />
      <div className="p-6 max-w-6xl space-y-6">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <Kpi label="Players" value={stats.playersTotal} hint={`${photoCoverage}% have a photo`} href="/players" />
          <Kpi label="Cards" value={stats.cardsTotal} hint={`${stats.cardsMinted} minted in circulation`} href="/cards" />
          <Kpi label="Teams" value={stats.teamsTotal} href="/teams" />
          <Kpi label="Users" value={stats.usersTotal} hint={`${stats.admins} admin${stats.admins === 1 ? '' : 's'}`} href="/users" />
        </div>

        <Panel>
          <div className="flex items-start justify-between gap-6 mb-3">
            <div>
              <div className="eyebrow-gold mb-1">Player photo coverage</div>
              <h3 className="text-base font-bold">{cutoutCoverage}% on transparent cutouts</h3>
              <p className="text-sm text-fg-muted mt-1 max-w-md leading-relaxed">
                Transparent PNG cutouts (TheSportsDB) render dramatically better than the white-background api-football headshots. Re-run <code className="font-mono text-gold bg-surface-2 px-1.5 py-0.5 rounded text-xs">npm run refresh:photos</code> in <code className="font-mono text-fg-soft text-xs">backend/</code> after roster updates.
              </p>
            </div>
            <Badge tone={cutoutCoverage >= 80 ? 'green' : cutoutCoverage >= 50 ? 'gold' : 'red'}>
              {cutoutCoverage >= 80 ? 'Healthy' : cutoutCoverage >= 50 ? 'Improving' : 'Needs refresh'}
            </Badge>
          </div>
          <div className="h-2 rounded-full bg-surface-3 overflow-hidden">
            <div className="h-full bg-gradient-to-r from-gold-deep to-gold" style={{ width: `${cutoutCoverage}%` }} />
          </div>
          <div className="flex items-center justify-between text-xs font-mono text-fg-muted mt-2">
            <span>{stats.playersWithCutout} / {stats.playersTotal} cutouts</span>
            <span>{photoCoverage}% any photo</span>
          </div>
        </Panel>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Panel>
            <div className="eyebrow-gold mb-1">Competitions</div>
            <div className="text-3xl font-extrabold tracking-tight">{stats.competitionsTotal}</div>
            <p className="text-sm text-fg-muted mt-2">
              World Cup 2026 + Big Five leagues + UEFA club competitions. Edit via the <Link href="/teams" className="text-gold hover:underline">Teams</Link> page or seed scripts.
            </p>
          </Panel>
          <Panel>
            <div className="eyebrow-gold mb-1">Matches indexed</div>
            <div className="text-3xl font-extrabold tracking-tight">{stats.matchesTotal.toLocaleString()}</div>
            <p className="text-sm text-fg-muted mt-2">
              Pulled in by the live ingest workers. Read-only here — match data is owned by the backend.
            </p>
          </Panel>
        </div>
      </div>
    </>
  );
}

function Kpi({ label, value, hint, href }: { label: string; value: number; hint?: string; href: string }) {
  return (
    <Link href={href} className="panel-strong p-5 block hover:border-gold/30 transition-colors group">
      <div className="eyebrow-gold mb-2">{label}</div>
      <div className="text-3xl font-extrabold tracking-tight text-fg group-hover:text-gold transition-colors">
        {value.toLocaleString()}
      </div>
      {hint && <div className="text-xs text-fg-muted mt-2">{hint}</div>}
    </Link>
  );
}
