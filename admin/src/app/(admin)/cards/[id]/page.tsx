import { apiServer, BackendError } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { Panel, Badge } from '@/components/ui';
import { CardPreview } from '@/components/card-preview';
import { CardEditForm } from './form';
import { notFound } from 'next/navigation';
import Link from 'next/link';

export const dynamic = 'force-dynamic';

const RARITIES = ['COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY', 'ICONIC'] as const;
type Rarity = typeof RARITIES[number];

interface Me { role: string; }
interface TemplateDetail {
  id: string;
  edition: string;
  rarity: Rarity;
  totalSupply: number;
  mintedCount: number;
  artUrl: string;
  frameStyle: string;
  giftableOnly: boolean;
  purchasable: boolean;
  gemPrice: number | null;
  player: {
    id: string;
    name: string;
    position: string | null;
    nationality: string | null;
    photoUrl: string | null;
    team: { name: string; shortName: string; crestUrl: string | null } | null;
  } | null;
}

export default async function CardEditPage({ params }: { params: { id: string } }) {
  let me: Me;
  let tpl: TemplateDetail;
  try {
    [me, tpl] = await Promise.all([
      apiServer<Me>('/admin/me'),
      apiServer<TemplateDetail>(`/admin/cards/${params.id}`),
    ]);
  } catch (e) {
    if (e instanceof BackendError && e.status === 404) notFound();
    throw e;
  }

  const remaining = Math.max(0, tpl.totalSupply - tpl.mintedCount);

  return (
    <>
      <Topbar title={`${tpl.player?.name ?? 'Untitled'} · ${tpl.rarity}`} role={me.role} />
      <div className="p-6 max-w-6xl">
        <div className="flex items-center gap-2 text-xs text-fg-muted mb-4">
          <Link href="/cards" className="hover:text-gold">Cards</Link>
          <span>/</span>
          <span className="text-fg-soft font-mono">{tpl.id}</span>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-[1fr_280px] gap-6">
          <div className="space-y-6">
            <CardEditForm
              template={{
                id: tpl.id,
                edition: tpl.edition,
                rarity: tpl.rarity,
                totalSupply: tpl.totalSupply,
                artUrl: tpl.artUrl,
                frameStyle: tpl.frameStyle,
                giftableOnly: tpl.giftableOnly,
                purchasable: tpl.purchasable,
                gemPrice: tpl.gemPrice == null ? '' : String(tpl.gemPrice),
              }}
              mintedCount={tpl.mintedCount}
              playerPhotoUrl={tpl.player?.photoUrl ?? null}
            />
          </div>

          <aside className="space-y-4">
            <div className="eyebrow-gold">Live preview</div>
            <CardPreview
              rarity={tpl.rarity}
              photoUrl={tpl.artUrl || tpl.player?.photoUrl || null}
              firstName={tpl.player?.name.split(' ').slice(0, -1).join(' ')}
              lastName={tpl.player?.name.split(' ').slice(-1)[0]}
              position={tpl.player?.position}
              country={tpl.player?.nationality}
              clubCrestUrl={tpl.player?.team?.crestUrl ?? null}
              editionLabel={tpl.edition}
            />

            <Panel className="!p-4">
              <div className="space-y-3 text-xs">
                <Row label="Rarity"><Badge tone={rarityTone(tpl.rarity)}>{tpl.rarity}</Badge></Row>
                <Row label="Minted"><span className="font-mono text-fg-soft">{tpl.mintedCount} / {tpl.totalSupply}</span></Row>
                <Row label="Remaining"><span className="font-mono text-fg-soft">{remaining}</span></Row>
                <Row label="Edition"><span className="font-mono text-fg-soft">{tpl.edition}</span></Row>
                <Row label="Frame"><span className="font-mono text-fg-soft">{tpl.frameStyle}</span></Row>
                {tpl.player && (
                  <Row label="Player">
                    <Link href={`/players/${tpl.player.id}`} className="text-gold hover:underline">
                      {tpl.player.name}
                    </Link>
                  </Row>
                )}
              </div>
            </Panel>

            <p className="text-[11px] text-fg-muted2 leading-relaxed">
              Editing the photo here writes to <code className="font-mono text-fg-soft">CardTemplate.artUrl</code> only. To update the underlying player photo (and cascade to every template), use the <Link href={tpl.player ? `/players/${tpl.player.id}` : '/players'} className="text-gold hover:underline">player editor</Link>.
            </p>
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

function rarityTone(r: string): 'gold' | 'neutral' | 'green' | 'blue' | 'red' {
  switch (r) {
    case 'ICONIC': case 'LEGENDARY': return 'gold';
    case 'EPIC': case 'RARE':         return 'blue';
    case 'UNCOMMON':                  return 'green';
    default:                          return 'neutral';
  }
}
