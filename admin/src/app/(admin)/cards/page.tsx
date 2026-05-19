import { apiServer } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { Table, THead, TH, TR, TD, Input, Badge, Empty } from '@/components/ui';
import Link from 'next/link';

export const dynamic = 'force-dynamic';

const PAGE_SIZE = 40;
const RARITIES = ['COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY', 'ICONIC'] as const;
type Rarity = typeof RARITIES[number];

interface CardRow {
  id: string;
  edition: string;
  rarity: Rarity;
  totalSupply: number;
  mintedCount: number;
  purchasable: boolean;
  player: { id: string; name: string } | null;
}
interface Me { role: string; }

export default async function CardsPage({
  searchParams,
}: {
  searchParams: { q?: string; rarity?: Rarity; playerId?: string; page?: string };
}) {
  const q = (searchParams.q ?? '').trim();
  const rarity = searchParams.rarity && RARITIES.includes(searchParams.rarity) ? searchParams.rarity : undefined;
  const playerId = searchParams.playerId?.trim();
  const page = Math.max(1, Number.parseInt(searchParams.page ?? '1', 10) || 1);

  const qs = new URLSearchParams();
  if (q) qs.set('q', q);
  if (rarity) qs.set('rarity', rarity);
  if (playerId) qs.set('playerId', playerId);
  qs.set('page', String(page));
  qs.set('pageSize', String(PAGE_SIZE));

  const [me, data] = await Promise.all([
    apiServer<Me>('/admin/me'),
    apiServer<{ rows: CardRow[]; total: number }>(`/admin/cards?${qs}`),
  ]);
  const pageCount = Math.max(1, Math.ceil(data.total / PAGE_SIZE));

  return (
    <>
      <Topbar title="Card Templates" role={me.role} />
      <div className="p-6 space-y-4">
        <form method="GET" className="flex flex-wrap items-center gap-3">
          <Input name="q" defaultValue={q} placeholder="Search by player name…" className="max-w-sm" />
          <div className="flex gap-1.5">
            <FilterChip name="rarity" value="" active={!rarity} label="All" />
            {RARITIES.map((r) => (
              <FilterChip key={r} name="rarity" value={r} active={rarity === r} label={r.slice(0, 3)} />
            ))}
          </div>
          {playerId && (
            <Link href="/cards" className="text-xs text-fg-muted hover:text-gold font-mono">
              clear playerId filter ×
            </Link>
          )}
          <div className="ml-auto text-xs font-mono text-fg-muted">
            {data.total.toLocaleString()} {data.total === 1 ? 'template' : 'templates'}
          </div>
        </form>

        {data.rows.length === 0 ? (
          <div className="panel-strong"><Empty title="No templates match" hint="Run npm run seed:cards in backend/ to populate." /></div>
        ) : (
          <Table>
            <THead>
              <TH>Player</TH>
              <TH>Edition</TH>
              <TH>Rarity</TH>
              <TH>Supply</TH>
              <TH>Minted</TH>
              <TH>Purchasable</TH>
              <TH />
            </THead>
            <tbody>
              {data.rows.map((t) => {
                const pct = t.totalSupply === 0 ? 0 : Math.round((t.mintedCount / t.totalSupply) * 100);
                return (
                  <TR key={t.id}>
                    <TD>
                      <Link href={`/cards/${t.id}`} className="font-medium text-fg hover:text-gold transition-colors">
                        {t.player?.name ?? '— no player —'}
                      </Link>
                      <div className="text-[10px] font-mono text-fg-muted2">{t.id.slice(0, 14)}…</div>
                    </TD>
                    <TD className="font-mono text-xs text-fg-soft">{t.edition}</TD>
                    <TD><Badge tone={rarityTone(t.rarity)}>{t.rarity}</Badge></TD>
                    <TD className="font-mono text-sm">{t.totalSupply}</TD>
                    <TD>
                      <div className="flex items-center gap-2">
                        <div className="w-16 h-1 bg-surface-3 rounded-full overflow-hidden">
                          <div className="h-full bg-gradient-to-r from-gold-deep to-gold" style={{ width: `${pct}%` }} />
                        </div>
                        <span className="font-mono text-xs text-fg-soft tabular-nums">{t.mintedCount}</span>
                      </div>
                    </TD>
                    <TD>{t.purchasable ? <Badge tone="green">Yes</Badge> : <Badge>No</Badge>}</TD>
                    <TD>
                      <Link href={`/cards/${t.id}`} className="text-gold hover:underline text-sm font-semibold">
                        Edit →
                      </Link>
                    </TD>
                  </TR>
                );
              })}
            </tbody>
          </Table>
        )}

        {pageCount > 1 && (
          <div className="flex items-center justify-between text-sm">
            <div className="text-fg-muted font-mono">Page {page} of {pageCount}</div>
            <div className="flex gap-2">
              <PageLink page={page - 1} q={q} rarity={rarity} playerId={playerId} disabled={page <= 1}>← Prev</PageLink>
              <PageLink page={page + 1} q={q} rarity={rarity} playerId={playerId} disabled={page >= pageCount}>Next →</PageLink>
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
          ? 'h-9 px-2.5 rounded-md text-[10px] font-bold font-mono bg-gold/15 text-gold border border-gold/30'
          : 'h-9 px-2.5 rounded-md text-[10px] font-bold font-mono bg-surface-1 text-fg-soft border border-border hover:border-gold/30'
      }
    >
      {label}
    </button>
  );
}

function PageLink({ page, q, rarity, playerId, disabled, children }: { page: number; q: string; rarity?: string; playerId?: string; disabled: boolean; children: React.ReactNode }) {
  if (disabled) return <span className="px-3 py-1.5 text-fg-muted2 text-xs">{children}</span>;
  const sp = new URLSearchParams();
  if (q) sp.set('q', q);
  if (rarity) sp.set('rarity', rarity);
  if (playerId) sp.set('playerId', playerId);
  sp.set('page', String(page));
  return (
    <Link href={`/cards?${sp.toString()}`} className="px-3 py-1.5 rounded-md bg-surface-2 hover:bg-surface-3 text-fg text-xs font-bold border border-border">
      {children}
    </Link>
  );
}

function rarityTone(r: string): 'gold' | 'neutral' | 'green' | 'blue' | 'red' {
  switch (r) {
    case 'ICONIC': case 'LEGENDARY': return 'gold';
    case 'EPIC': case 'RARE':         return 'blue';
    case 'UNCOMMON':                  return 'green';
    default:                          return 'neutral';
  }
}
