import Link from 'next/link';
import type { ReactNode } from 'react';
import { apiServer } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { Panel, SectionHead, Badge, Table, THead, TH, TR, TD, Empty } from '@/components/ui';
import { GemsEditor } from './gems-form';

export const dynamic = 'force-dynamic';

interface Me { role: 'USER' | 'ADMIN' | 'SUPERADMIN'; }

interface GemTxn {
  id: string;
  amount: number;
  source: string;
  description: string | null;
  balanceAfter: number;
  createdAt: string;
}
interface FavTeam {
  id: string;
  name: string | null;
  shortName: string | null;
  crestUrl: string | null;
  countryCode: string | null;
}
interface LeagueMembership {
  id: string;
  name: string;
  isOwner: boolean;
  joinedAt: string;
}
interface UserDetail {
  id: string;
  email: string | null;
  displayName: string | null;
  userTag: string | null;
  role: 'USER' | 'ADMIN' | 'SUPERADMIN';
  photoUrl: string | null;
  countryCode: string | null;
  supportedCountryCode: string | null;
  coins: number;
  gems: number;
  proExpiresAt: string | null;
  proActive: boolean;
  favouriteTeams: string[];
  favouriteTeamDetails: FavTeam[];
  leagues: LeagueMembership[];
  fcmTokenCount: number;
  lastDailyClaimAt: string | null;
  welcomeCardSeenAt: string | null;
  createdAt: string;
  updatedAt: string;
  _count: {
    ownedCards: number;
    predictions: number;
    fantasyLineups: number;
    achievements: number;
    gemTransactions: number;
    leagueMemberships: number;
  };
  gemHistory: GemTxn[];
}

function fmt(dt: string | null): string {
  if (!dt) return '—';
  return new Date(dt).toLocaleString(undefined, {
    year: 'numeric', month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit',
  });
}

function Info({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-1 py-2.5 border-b border-border last:border-0">
      <span className="eyebrow-gold !text-[9px]">{label}</span>
      <span className="text-sm text-fg break-words">{children}</span>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="panel-strong px-4 py-3 text-center">
      <div className="font-mono text-xl font-bold text-fg tabular-nums">{value.toLocaleString()}</div>
      <div className="eyebrow-gold !text-[9px] mt-1 !text-fg-muted">{label}</div>
    </div>
  );
}

function TeamChip({ team }: { team: FavTeam }) {
  const label = team.name ?? team.shortName ?? team.id;
  return (
    <div className="flex items-center gap-2 rounded-full border border-border bg-surface-2 pl-1.5 pr-3 py-1">
      {team.crestUrl ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={team.crestUrl} alt="" width={22} height={22} className="h-[22px] w-[22px] rounded-full object-contain" />
      ) : (
        <span className="flex h-[22px] w-[22px] items-center justify-center rounded-full bg-surface text-[9px] font-mono text-fg-muted">
          {(team.shortName ?? team.id).slice(0, 3).toUpperCase()}
        </span>
      )}
      <span className="text-sm text-fg">{label}</span>
      {!team.name && (
        <span className="text-[10px] font-mono text-live" title="No matching team row">unknown</span>
      )}
    </div>
  );
}

export default async function UserDetailPage({ params }: { params: { id: string } }) {
  const [me, u] = await Promise.all([
    apiServer<Me>('/admin/me'),
    apiServer<UserDetail>(`/admin/users/${params.id}`),
  ]);

  return (
    <>
      <Topbar title="User" role={me.role} />
      <div className="p-6 space-y-6 max-w-5xl">
        <Link href="/users" className="text-sm text-fg-muted hover:text-gold">← All users</Link>

        {/* Header */}
        <Panel>
          <div className="flex items-center gap-4">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={u.photoUrl || '/logo.png'}
              alt=""
              width={56}
              height={56}
              className="h-14 w-14 rounded-full object-cover border border-border bg-surface-2"
            />
            <div className="min-w-0">
              <div className="flex items-center gap-2 flex-wrap">
                <h2 className="text-xl font-bold text-fg">{u.displayName ?? '—'}</h2>
                <Badge tone={u.role === 'SUPERADMIN' ? 'gold' : u.role === 'ADMIN' ? 'blue' : 'neutral'}>{u.role}</Badge>
                {u.proActive && <Badge tone="gold">PRO</Badge>}
              </div>
              <div className="text-sm text-gold font-mono">{u.userTag ? `@${u.userTag}` : 'no tag'}</div>
              <div className="text-[11px] font-mono text-fg-muted2 mt-0.5">{u.id}</div>
            </div>
          </div>
        </Panel>

        {/* Gem editor */}
        <Panel>
          <SectionHead eyebrow="Currency" title="Gems" />
          <GemsEditor userId={u.id} currentGems={u.gems} />
        </Panel>

        {/* Counts */}
        <div className="grid grid-cols-3 sm:grid-cols-6 gap-3">
          <Stat label="Cards" value={u._count.ownedCards} />
          <Stat label="Predictions" value={u._count.predictions} />
          <Stat label="Lineups" value={u._count.fantasyLineups} />
          <Stat label="Achievements" value={u._count.achievements} />
          <Stat label="Leagues" value={u._count.leagueMemberships} />
          <Stat label="Gem txns" value={u._count.gemTransactions} />
        </div>

        {/* Following */}
        <Panel>
          <SectionHead eyebrow="Following" title="Teams followed" />
          {u.favouriteTeamDetails.length === 0 ? (
            <Empty title="Not following any teams" />
          ) : (
            <div className="flex flex-wrap gap-2">
              {u.favouriteTeamDetails.map((t) => <TeamChip key={t.id} team={t} />)}
            </div>
          )}
        </Panel>

        {/* Fantasy leagues */}
        <Panel>
          <SectionHead eyebrow="Fantasy" title="Leagues" />
          {u.leagues.length === 0 ? (
            <Empty title="Not a member of any fantasy league" />
          ) : (
            <div className="flex flex-col">
              {u.leagues.map((l) => (
                <div key={l.id} className="flex items-center gap-2 py-2.5 border-b border-border last:border-0">
                  <span className="text-sm text-fg">{l.name}</span>
                  {l.isOwner && <Badge tone="gold">OWNER</Badge>}
                  <span className="ml-auto text-xs font-mono text-fg-muted whitespace-nowrap">joined {fmt(l.joinedAt)}</span>
                </div>
              ))}
            </div>
          )}
        </Panel>

        {/* Profile fields */}
        <Panel>
          <SectionHead eyebrow="Profile" title="Account details" />
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-10">
            <Info label="Email">{u.email ?? '—'}</Info>
            <Info label="Coins">{u.coins.toLocaleString()}</Info>
            <Info label="Gems">{u.gems.toLocaleString()}</Info>
            <Info label="Pro">{u.proActive ? `Active until ${fmt(u.proExpiresAt)}` : 'Not active'}</Info>
            <Info label="Country">{u.countryCode ?? '—'}</Info>
            <Info label="Supports (WC)">{u.supportedCountryCode ?? '—'}</Info>
            <Info label="Teams followed">{u.favouriteTeamDetails.length}</Info>
            <Info label="Push devices">{u.fcmTokenCount}</Info>
            <Info label="Last daily claim">{fmt(u.lastDailyClaimAt)}</Info>
            <Info label="Welcome card seen">{fmt(u.welcomeCardSeenAt)}</Info>
            <Info label="Joined">{fmt(u.createdAt)}</Info>
            <Info label="Updated">{fmt(u.updatedAt)}</Info>
          </div>
        </Panel>

        {/* Gem ledger */}
        <div>
          <SectionHead eyebrow="Audit" title="Recent gem activity" />
          {u.gemHistory.length === 0 ? (
            <div className="panel-strong"><Empty title="No gem transactions yet" /></div>
          ) : (
            <Table>
              <THead>
                <TH>When</TH>
                <TH>Source</TH>
                <TH>Detail</TH>
                <TH className="text-right">Change</TH>
                <TH className="text-right">Balance</TH>
              </THead>
              <tbody>
                {u.gemHistory.map((t) => (
                  <TR key={t.id}>
                    <TD className="text-xs font-mono text-fg-muted whitespace-nowrap">{fmt(t.createdAt)}</TD>
                    <TD><Badge>{t.source}</Badge></TD>
                    <TD className="text-sm text-fg-soft">{t.description ?? '—'}</TD>
                    <TD className={`text-right font-mono text-sm tabular-nums ${t.amount >= 0 ? 'text-pitch' : 'text-live'}`}>
                      {t.amount >= 0 ? '+' : ''}{t.amount.toLocaleString()}
                    </TD>
                    <TD className="text-right font-mono text-sm text-fg tabular-nums">{t.balanceAfter.toLocaleString()}</TD>
                  </TR>
                ))}
              </tbody>
            </Table>
          )}
        </div>
      </div>
    </>
  );
}
