import { apiServer, BackendError } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { Panel, Badge, SectionHead } from '@/components/ui';
import { CardPreview } from '@/components/card-preview';
import { PlayerEditForm } from './form';
import { notFound } from 'next/navigation';
import Link from 'next/link';
import Image from 'next/image';

export const dynamic = 'force-dynamic';

interface Me { role: string; }
interface PlayerDetail {
  id: string;
  name: string;
  photoUrl: string | null;
  position: string | null;
  nationality: string | null;
  shirtNumber: number | null;
  dateOfBirth: string | null;
  teamId: string;
  team: { id: string; name: string; shortName: string; crestUrl: string | null } | null;
  cardTemplates: {
    id: string;
    edition: string;
    rarity: string;
    totalSupply: number;
    mintedCount: number;
    artUrl: string;
  }[];
}
interface TeamOpt { id: string; name: string; shortName: string | null; }

export default async function PlayerDetailPage({ params }: { params: { id: string } }) {
  let me: Me;
  let player: PlayerDetail;
  let teams: { rows: TeamOpt[] };
  try {
    [me, player, teams] = await Promise.all([
      apiServer<Me>('/admin/me'),
      apiServer<PlayerDetail>(`/admin/players/${params.id}`),
      apiServer<{ rows: TeamOpt[] }>('/admin/teams?pageSize=500'),
    ]);
  } catch (e) {
    if (e instanceof BackendError && e.status === 404) notFound();
    throw e;
  }

  return (
    <>
      <Topbar title={player.name} role={me.role} />
      <div className="p-6 max-w-6xl">
        <div className="flex items-center gap-2 text-xs text-fg-muted mb-4">
          <Link href="/players" className="hover:text-gold">Players</Link>
          <span>/</span>
          <span className="text-fg-soft font-mono">{player.id}</span>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-[1fr_280px] gap-6">
          <div className="space-y-6">
            <PlayerEditForm
              player={{
                id: player.id,
                name: player.name,
                photoUrl: player.photoUrl ?? '',
                position: player.position ?? '',
                nationality: player.nationality ?? '',
                shirtNumber: player.shirtNumber == null ? '' : String(player.shirtNumber),
                teamId: player.teamId,
              }}
              teams={teams.rows.map((t) => ({ id: t.id, name: t.name, shortName: t.shortName }))}
              clubCrestUrl={player.team?.crestUrl ?? null}
            />

            <Panel>
              <SectionHead
                eyebrow="Cascade impact"
                title={`${player.cardTemplates.length} card template${player.cardTemplates.length === 1 ? '' : 's'} reference this player`}
                action={
                  <Link href={`/cards?playerId=${player.id}`} className="text-sm font-semibold text-gold hover:underline">
                    View →
                  </Link>
                }
              />
              {player.cardTemplates.length === 0 ? (
                <p className="text-sm text-fg-muted">
                  No card templates link to this player yet. Run <code className="font-mono text-gold bg-surface-2 px-1.5 py-0.5 rounded text-xs">npm run seed:cards</code> in <code className="font-mono text-fg-soft text-xs">backend/</code> to mint them.
                </p>
              ) : (
                <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                  {player.cardTemplates.map((t) => (
                    <Link key={t.id} href={`/cards/${t.id}`} className="bg-surface-2 border border-border rounded-md p-3 hover:border-gold/40 transition-colors">
                      <div className="flex items-center justify-between mb-1">
                        <Badge tone={rarityTone(t.rarity)}>{t.rarity}</Badge>
                        <span className="text-[10px] font-mono text-fg-muted2">{t.mintedCount}/{t.totalSupply}</span>
                      </div>
                      <div className="text-xs font-mono text-fg-soft truncate">{t.edition}</div>
                    </Link>
                  ))}
                </div>
              )}
              <p className="text-xs text-fg-muted2 mt-3">
                Saving here also rewrites <code className="font-mono">artUrl</code> on every template above, in a single backend transaction.
              </p>
            </Panel>
          </div>

          <aside className="space-y-4">
            <div className="eyebrow-gold">Live preview</div>
            <PreviewWrapper player={player} />
            <Panel className="!p-4">
              <div className="text-xs space-y-2">
                <Row label="Team">
                  <div className="flex items-center gap-1.5">
                    {player.team?.crestUrl && <Image src={player.team.crestUrl} alt="" width={14} height={14} unoptimized />}
                    <span className="text-fg-soft">{player.team?.name ?? '—'}</span>
                  </div>
                </Row>
                <Row label="DOB">
                  <span className="font-mono text-fg-soft">
                    {player.dateOfBirth ? player.dateOfBirth.slice(0, 10) : '—'}
                  </span>
                </Row>
                <Row label="Source">{photoBadge(player.photoUrl)}</Row>
              </div>
            </Panel>
          </aside>
        </div>
      </div>
    </>
  );
}

function PreviewWrapper({ player }: { player: PlayerDetail }) {
  const tokens = player.name.split(/\s+/);
  const lastName = tokens[tokens.length - 1];
  const firstName = tokens.slice(0, -1).join(' ');
  return (
    <CardPreview
      rarity="EPIC"
      photoUrl={player.photoUrl}
      firstName={firstName}
      lastName={lastName}
      position={player.position}
      country={player.nationality}
      clubCrestUrl={player.team?.crestUrl ?? null}
      editionLabel="WC2026-BASE"
    />
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

function photoBadge(url: string | null) {
  if (!url) return <Badge tone="red">Missing</Badge>;
  if (url.includes('thesportsdb.com')) return <Badge tone="green">Cutout</Badge>;
  return <Badge tone="gold">Legacy</Badge>;
}
