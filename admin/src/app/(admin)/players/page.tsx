import { apiServer } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { Table, THead, TH, TR, TD, Input, Badge, Empty } from '@/components/ui';
import Link from 'next/link';
import Image from 'next/image';

export const dynamic = 'force-dynamic';

const PAGE_SIZE = 30;

interface PlayerRow {
  id: string;
  name: string;
  photoUrl: string | null;
  position: string | null;
  nationality: string | null;
  team: { name: string; shortName: string; crestUrl: string | null } | null;
}
interface Me { role: string; }

export default async function PlayersPage({
  searchParams,
}: {
  searchParams: { q?: string; photo?: 'cutout' | 'any' | 'none'; page?: string };
}) {
  const q = (searchParams.q ?? '').trim();
  const photoFilter = searchParams.photo;
  const page = Math.max(1, Number.parseInt(searchParams.page ?? '1', 10) || 1);

  const qs = new URLSearchParams();
  if (q) qs.set('q', q);
  if (photoFilter) qs.set('photo', photoFilter);
  qs.set('page', String(page));
  qs.set('pageSize', String(PAGE_SIZE));

  const [me, data] = await Promise.all([
    apiServer<Me>('/admin/me'),
    apiServer<{ rows: PlayerRow[]; total: number }>(`/admin/players?${qs}`),
  ]);
  const pageCount = Math.max(1, Math.ceil(data.total / PAGE_SIZE));

  return (
    <>
      <Topbar title="Players" role={me.role} />
      <div className="p-6 space-y-4">
        <form className="flex flex-wrap items-center gap-3" method="GET">
          <Input name="q" defaultValue={q} placeholder="Search by name…" className="max-w-sm" />
          <div className="flex gap-2">
            <FilterChip name="photo" value="" active={!photoFilter} label="All" />
            <FilterChip name="photo" value="cutout" active={photoFilter === 'cutout'} label="Cutouts" />
            <FilterChip name="photo" value="any" active={photoFilter === 'any'} label="Any photo" />
            <FilterChip name="photo" value="none" active={photoFilter === 'none'} label="Missing" />
          </div>
          <div className="ml-auto text-xs font-mono text-fg-muted">
            {data.total.toLocaleString()} {data.total === 1 ? 'player' : 'players'}
          </div>
        </form>

        {data.rows.length === 0 ? (
          <div className="panel-strong"><Empty title="No players match" hint="Try clearing the filter or running the roster seed." /></div>
        ) : (
          <Table>
            <THead>
              <TH className="w-12" />
              <TH>Player</TH>
              <TH>Team</TH>
              <TH>Position</TH>
              <TH>Nationality</TH>
              <TH>Photo</TH>
              <TH />
            </THead>
            <tbody>
              {data.rows.map((p) => (
                <TR key={p.id}>
                  <TD>
                    <div className="w-9 h-12 rounded bg-surface-2 overflow-hidden relative">
                      {p.photoUrl && (
                        <Image src={p.photoUrl} alt="" fill sizes="36px" className="object-contain object-bottom" unoptimized />
                      )}
                    </div>
                  </TD>
                  <TD>
                    <Link href={`/players/${p.id}`} className="font-medium text-fg hover:text-gold transition-colors">
                      {p.name}
                    </Link>
                    <div className="text-[10px] font-mono text-fg-muted2">{p.id}</div>
                  </TD>
                  <TD>
                    <div className="flex items-center gap-2">
                      {p.team?.crestUrl && (
                        <Image src={p.team.crestUrl} alt="" width={16} height={16} className="rounded-sm" unoptimized />
                      )}
                      <span className="text-fg-soft text-sm">{p.team?.shortName ?? p.team?.name ?? '—'}</span>
                    </div>
                  </TD>
                  <TD className="text-fg-soft text-sm">{p.position ?? '—'}</TD>
                  <TD className="text-fg-soft text-sm">{p.nationality ?? '—'}</TD>
                  <TD>{photoBadge(p.photoUrl)}</TD>
                  <TD>
                    <Link href={`/players/${p.id}`} className="text-gold hover:underline text-sm font-semibold">
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
              <PageLink page={page - 1} q={q} photo={photoFilter} disabled={page <= 1}>← Prev</PageLink>
              <PageLink page={page + 1} q={q} photo={photoFilter} disabled={page >= pageCount}>Next →</PageLink>
            </div>
          </div>
        )}
      </div>
    </>
  );
}

function FilterChip({ name, value, label, active }: { name: string; value: string; label: string; active: boolean }) {
  return (
    <button
      type="submit"
      name={name}
      value={value}
      className={
        active
          ? 'h-9 px-3 rounded-md text-xs font-bold bg-gold/15 text-gold border border-gold/30'
          : 'h-9 px-3 rounded-md text-xs font-bold bg-surface-1 text-fg-soft border border-border hover:border-gold/30'
      }
    >
      {label}
    </button>
  );
}

function PageLink({ page, q, photo, disabled, children }: { page: number; q: string; photo?: string; disabled: boolean; children: React.ReactNode }) {
  if (disabled) return <span className="px-3 py-1.5 text-fg-muted2 text-xs">{children}</span>;
  const sp = new URLSearchParams();
  if (q) sp.set('q', q);
  if (photo) sp.set('photo', photo);
  sp.set('page', String(page));
  return (
    <Link href={`/players?${sp.toString()}`} className="px-3 py-1.5 rounded-md bg-surface-2 hover:bg-surface-3 text-fg text-xs font-bold border border-border">
      {children}
    </Link>
  );
}

function photoBadge(url: string | null) {
  if (!url) return <Badge tone="red">Missing</Badge>;
  if (url.includes('thesportsdb.com')) return <Badge tone="green">Cutout</Badge>;
  return <Badge tone="gold">Legacy</Badge>;
}
