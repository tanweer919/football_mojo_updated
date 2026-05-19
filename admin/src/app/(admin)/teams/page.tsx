import { apiServer } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { Table, THead, TH, TR, TD, Input, Empty } from '@/components/ui';
import Link from 'next/link';
import Image from 'next/image';

export const dynamic = 'force-dynamic';

const PAGE_SIZE = 40;

interface TeamRow {
  id: string;
  name: string;
  shortName: string;
  countryCode: string | null;
  crestUrl: string | null;
  competition: { id: string; name: string } | null;
  _count: { players: number };
}
interface CompOpt { id: string; name: string; }
interface Me { role: string; }

export default async function TeamsPage({
  searchParams,
}: {
  searchParams: { q?: string; competitionId?: string; page?: string };
}) {
  const q = (searchParams.q ?? '').trim();
  const competitionId = searchParams.competitionId?.trim() || undefined;
  const page = Math.max(1, Number.parseInt(searchParams.page ?? '1', 10) || 1);

  const qs = new URLSearchParams();
  if (q) qs.set('q', q);
  if (competitionId) qs.set('competitionId', competitionId);
  qs.set('page', String(page));
  qs.set('pageSize', String(PAGE_SIZE));

  const [me, data] = await Promise.all([
    apiServer<Me>('/admin/me'),
    apiServer<{ rows: TeamRow[]; total: number; competitions: CompOpt[] }>(`/admin/teams?${qs}`),
  ]);
  const pageCount = Math.max(1, Math.ceil(data.total / PAGE_SIZE));

  return (
    <>
      <Topbar title="Teams" role={me.role} />
      <div className="p-6 space-y-4">
        <form method="GET" className="flex flex-wrap items-center gap-3">
          <Input name="q" defaultValue={q} placeholder="Search teams…" className="max-w-sm" />
          <select
            name="competitionId"
            defaultValue={competitionId ?? ''}
            className="h-10 bg-surface-1 border border-border rounded-md px-3 text-sm text-fg cursor-pointer"
          >
            <option value="">All competitions</option>
            {data.competitions.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
          <button type="submit" className="h-10 px-4 rounded-md bg-surface-2 border border-border text-sm font-bold text-fg hover:border-gold/30">
            Apply
          </button>
          <div className="ml-auto text-xs font-mono text-fg-muted">
            {data.total.toLocaleString()} {data.total === 1 ? 'team' : 'teams'}
          </div>
        </form>

        {data.rows.length === 0 ? (
          <div className="panel-strong"><Empty title="No teams match" /></div>
        ) : (
          <Table>
            <THead>
              <TH className="w-12" />
              <TH>Name</TH>
              <TH>Short</TH>
              <TH>Country</TH>
              <TH>Competition</TH>
              <TH>Players</TH>
              <TH />
            </THead>
            <tbody>
              {data.rows.map((t) => (
                <TR key={t.id}>
                  <TD>
                    {t.crestUrl && (
                      <div className="w-8 h-8 rounded bg-surface-2 flex items-center justify-center">
                        <Image src={t.crestUrl} alt="" width={28} height={28} className="object-contain" unoptimized />
                      </div>
                    )}
                  </TD>
                  <TD>
                    <Link href={`/teams/${t.id}`} className="font-medium text-fg hover:text-gold transition-colors">
                      {t.name}
                    </Link>
                    <div className="text-[10px] font-mono text-fg-muted2">{t.id}</div>
                  </TD>
                  <TD className="font-mono text-xs text-fg-soft">{t.shortName}</TD>
                  <TD className="font-mono text-xs text-fg-soft">{t.countryCode ?? '—'}</TD>
                  <TD className="text-fg-soft text-sm">{t.competition?.name ?? '—'}</TD>
                  <TD className="font-mono text-sm text-fg-soft">{t._count.players}</TD>
                  <TD>
                    <Link href={`/teams/${t.id}`} className="text-gold hover:underline text-sm font-semibold">
                      Edit →
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
              <PageLink page={page - 1} q={q} competitionId={competitionId} disabled={page <= 1}>← Prev</PageLink>
              <PageLink page={page + 1} q={q} competitionId={competitionId} disabled={page >= pageCount}>Next →</PageLink>
            </div>
          </div>
        )}
      </div>
    </>
  );
}

function PageLink({ page, q, competitionId, disabled, children }: { page: number; q: string; competitionId?: string; disabled: boolean; children: React.ReactNode }) {
  if (disabled) return <span className="px-3 py-1.5 text-fg-muted2 text-xs">{children}</span>;
  const sp = new URLSearchParams();
  if (q) sp.set('q', q);
  if (competitionId) sp.set('competitionId', competitionId);
  sp.set('page', String(page));
  return (
    <Link href={`/teams?${sp.toString()}`} className="px-3 py-1.5 rounded-md bg-surface-2 hover:bg-surface-3 text-fg text-xs font-bold border border-border">
      {children}
    </Link>
  );
}
