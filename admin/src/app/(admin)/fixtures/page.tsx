import { apiServer } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { Table, THead, TH, TR, TD, Input, Empty, Badge } from '@/components/ui';
import Link from 'next/link';

export const dynamic = 'force-dynamic';

const PAGE_SIZE = 40;

interface FixtureRow {
  id: string;
  kickoffAt: string;
  status: string;
  homeTeam: { name: string };
  awayTeam: { name: string };
  competition: { name: string } | null;
  _count: { watchLinks: number };
}
interface Me { role: string; }

function fmt(iso: string) {
  return new Date(iso).toLocaleString(undefined, {
    day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit',
  });
}

export default async function FixturesPage({
  searchParams,
}: {
  searchParams: { q?: string; page?: string };
}) {
  const q = (searchParams.q ?? '').trim();
  const page = Math.max(1, Number.parseInt(searchParams.page ?? '1', 10) || 1);

  const qs = new URLSearchParams();
  if (q) qs.set('q', q);
  qs.set('page', String(page));
  qs.set('pageSize', String(PAGE_SIZE));

  const [me, data] = await Promise.all([
    apiServer<Me>('/admin/me'),
    apiServer<{ rows: FixtureRow[]; total: number }>(`/admin/fixtures?${qs}`),
  ]);
  const pageCount = Math.max(1, Math.ceil(data.total / PAGE_SIZE));

  return (
    <>
      <Topbar title="Fixtures" role={me.role} />
      <div className="p-6 space-y-4">
        <form method="GET" className="flex flex-wrap items-center gap-3">
          <Input name="q" defaultValue={q} placeholder="Search by team…" className="max-w-sm" />
          <button type="submit" className="h-10 px-4 rounded-md bg-surface-2 border border-border text-sm font-bold text-fg hover:border-gold/30">
            Apply
          </button>
          <div className="ml-auto text-xs font-mono text-fg-muted">
            {data.total.toLocaleString()} {data.total === 1 ? 'fixture' : 'fixtures'}
          </div>
        </form>

        {data.rows.length === 0 ? (
          <div className="panel-strong"><Empty title="No fixtures match" hint="Try a different team name." /></div>
        ) : (
          <Table>
            <THead>
              <TH>Match</TH>
              <TH>Competition</TH>
              <TH>Kickoff</TH>
              <TH>Status</TH>
              <TH>Watch links</TH>
              <TH />
            </THead>
            <tbody>
              {data.rows.map((m) => (
                <TR key={m.id}>
                  <TD>
                    <Link href={`/fixtures/${m.id}`} className="font-medium text-fg hover:text-gold transition-colors">
                      {m.homeTeam.name} <span className="text-fg-muted2">v</span> {m.awayTeam.name}
                    </Link>
                    <div className="text-[10px] font-mono text-fg-muted2">{m.id}</div>
                  </TD>
                  <TD className="text-fg-soft text-sm">{m.competition?.name ?? '—'}</TD>
                  <TD className="font-mono text-xs text-fg-soft">{fmt(m.kickoffAt)}</TD>
                  <TD><Badge tone={m.status === 'LIVE' ? 'gold' : 'neutral'}>{m.status}</Badge></TD>
                  <TD className="font-mono text-sm text-fg-soft">
                    {m._count.watchLinks > 0
                      ? <span className="text-pitch">{m._count.watchLinks}</span>
                      : <span className="text-fg-muted2">0</span>}
                  </TD>
                  <TD>
                    <Link href={`/fixtures/${m.id}`} className="text-gold hover:underline text-sm font-semibold">
                      Manage →
                    </Link>
                  </TD>
                </TR>
              ))}
            </tbody>
          </Table>
        )}

        {pageCount > 1 && (
          <div className="flex items-center justify-between text-sm">
            <div className="text-fg-muted font-mono">Page {page} of {pageCount}</div>
            <div className="flex gap-2">
              <PageLink page={page - 1} q={q} disabled={page <= 1}>← Prev</PageLink>
              <PageLink page={page + 1} q={q} disabled={page >= pageCount}>Next →</PageLink>
            </div>
          </div>
        )}
      </div>
    </>
  );
}

function PageLink({ page, q, disabled, children }: { page: number; q: string; disabled: boolean; children: React.ReactNode }) {
  if (disabled) return <span className="px-3 py-1.5 text-fg-muted2 text-xs">{children}</span>;
  const sp = new URLSearchParams();
  if (q) sp.set('q', q);
  sp.set('page', String(page));
  return (
    <Link href={`/fixtures?${sp.toString()}`} className="px-3 py-1.5 rounded-md bg-surface-2 hover:bg-surface-3 text-fg text-xs font-bold border border-border">
      {children}
    </Link>
  );
}
