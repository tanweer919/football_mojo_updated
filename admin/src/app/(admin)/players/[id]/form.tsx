'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Field, Input, Select, Button, Panel, SectionHead, Badge } from '@/components/ui';
import { CardPreview } from '@/components/card-preview';
import { api } from '@/lib/api-client';

interface PlayerFormValues {
  id: string;
  name: string;
  photoUrl: string;
  position: string;
  nationality: string;
  shirtNumber: string;
  teamId: string;
}

/**
 * Client form. Mutations now go through `api()` → Next.js proxy → backend
 * (`PATCH /v1/admin/players/:id` and `POST /v1/admin/players/:id/refresh-photo`).
 * No direct Prisma calls from Next.js — all writes flow through the
 * AdminPlayersService where the cascade transaction lives.
 */
export function PlayerEditForm({
  player,
  teams,
  clubCrestUrl,
}: {
  player: PlayerFormValues;
  teams: { id: string; name: string; shortName: string | null }[];
  clubCrestUrl: string | null;
}) {
  const [values, setValues] = useState(player);
  const [savedAt, setSavedAt] = useState<Date | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const [refreshing, setRefreshing] = useState(false);
  const router = useRouter();

  const dirty =
    values.name !== player.name ||
    values.photoUrl !== player.photoUrl ||
    values.position !== player.position ||
    values.nationality !== player.nationality ||
    values.shirtNumber !== player.shirtNumber ||
    values.teamId !== player.teamId;

  function set<K extends keyof PlayerFormValues>(k: K, v: PlayerFormValues[K]) {
    setValues((prev) => ({ ...prev, [k]: v }));
    setError(null);
  }

  function onSave() {
    setError(null);
    startTransition(async () => {
      try {
        const shirt = values.shirtNumber.trim();
        const shirtNumber = shirt === '' ? null : Number.parseInt(shirt, 10);
        if (shirtNumber !== null && !Number.isFinite(shirtNumber)) {
          throw new Error('Shirt number must be a whole number.');
        }
        await api(`/players/${values.id}`, {
          method: 'PATCH',
          body: JSON.stringify({
            name: values.name.trim(),
            photoUrl: values.photoUrl.trim() || null,
            position: values.position.trim() || null,
            nationality: values.nationality.trim() || null,
            shirtNumber,
            teamId: values.teamId.trim(),
          }),
        });
        setSavedAt(new Date());
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  async function onRefreshPhoto() {
    setError(null);
    setRefreshing(true);
    try {
      const { url, matched } = await api<{ url: string; matched: string }>(
        `/players/${player.id}/refresh-photo`,
        { method: 'POST' },
      );
      set('photoUrl', url);
      setSavedAt(new Date());
      router.refresh();
      console.log('TheSportsDB matched:', matched);
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setRefreshing(false);
    }
  }

  return (
    <Panel>
      <SectionHead
        eyebrow="Player record"
        title="Identity & photo"
        action={
          <div className="flex items-center gap-3">
            {dirty && <Badge tone="gold">Unsaved</Badge>}
            {savedAt && !dirty && (
              <span className="text-xs font-mono text-pitch">Saved {savedAt.toLocaleTimeString()}</span>
            )}
          </div>
        }
      />

      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <Field label="Display name">
          <Input value={values.name} onChange={(e) => set('name', e.target.value)} />
        </Field>
        <Field label="Shirt #" hint="Leave blank if unknown.">
          <Input
            value={values.shirtNumber}
            onChange={(e) => set('shirtNumber', e.target.value.replace(/[^\d]/g, ''))}
            inputMode="numeric"
          />
        </Field>
        <Field label="Position" hint="GK · DEF · MID · FWD">
          <Select value={values.position} onChange={(e) => set('position', e.target.value)}>
            <option value="">—</option>
            <option value="GK">GK</option>
            <option value="DEF">DEF</option>
            <option value="MID">MID</option>
            <option value="FWD">FWD</option>
          </Select>
        </Field>
        <Field label="Nationality" hint="Free-form (e.g. England, Japan).">
          <Input value={values.nationality} onChange={(e) => set('nationality', e.target.value)} />
        </Field>
        <Field label="Team" className="md:col-span-2">
          <Select value={values.teamId} onChange={(e) => set('teamId', e.target.value)}>
            {teams.map((t) => (
              <option key={t.id} value={t.id}>
                {t.name}
              </option>
            ))}
          </Select>
        </Field>
      </div>

      <div className="mt-6 pt-6 border-t border-border">
        <div className="flex items-end justify-between gap-3 mb-3">
          <div>
            <div className="eyebrow-gold">Photo URL</div>
            <p className="text-xs text-fg-muted mt-1 max-w-md leading-relaxed">
              Prefer transparent PNG cutouts from TheSportsDB — they render dramatically better on cards than white-background headshots.
            </p>
          </div>
          <Button type="button" size="sm" variant="soft" onClick={onRefreshPhoto} disabled={refreshing || pending}>
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 12a9 9 0 0 1 15-6.7L21 8M21 3v5h-5M21 12a9 9 0 0 1-15 6.7L3 16M3 21v-5h5" />
            </svg>
            {refreshing ? 'Fetching…' : 'Fetch from TheSportsDB'}
          </Button>
        </div>
        <Input
          value={values.photoUrl}
          onChange={(e) => set('photoUrl', e.target.value)}
          placeholder="https://r2.thesportsdb.com/images/media/player/cutout/…"
          className="font-mono text-xs"
        />

        <div className="grid grid-cols-1 sm:grid-cols-[160px_1fr] gap-4 mt-4">
          <div className="w-[160px]">
            <CardPreview
              rarity="EPIC"
              photoUrl={values.photoUrl || null}
              firstName={values.name.split(' ').slice(0, -1).join(' ')}
              lastName={values.name.split(' ').slice(-1)[0]}
              position={values.position}
              country={values.nationality}
              clubCrestUrl={clubCrestUrl}
              editionLabel="WC2026-BASE"
            />
          </div>
          <div className="space-y-2 text-xs">
            <div className="text-fg-muted">
              <span className="eyebrow !text-[8px] block mb-1">Detected source</span>
              {detectSource(values.photoUrl)}
            </div>
            {values.photoUrl && (
              <a
                href={values.photoUrl}
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-1 text-gold hover:underline font-mono text-[11px] break-all"
              >
                Open raw image ↗
              </a>
            )}
          </div>
        </div>
      </div>

      {error && (
        <div className="mt-4 p-3 rounded-md bg-live/10 border border-live/30 text-live text-xs">
          {error}
        </div>
      )}

      <div className="mt-6 pt-5 border-t border-border flex items-center justify-end gap-3">
        <Button type="button" variant="ghost" onClick={() => setValues(player)} disabled={!dirty || pending}>
          Reset
        </Button>
        <Button type="button" variant="gold" onClick={onSave} disabled={!dirty || pending}>
          {pending ? 'Saving…' : 'Save changes'}
        </Button>
      </div>
    </Panel>
  );
}

function detectSource(url: string) {
  if (!url.trim()) return <Badge tone="red">Empty</Badge>;
  if (url.includes('thesportsdb.com')) return <Badge tone="green">Transparent cutout</Badge>;
  if (url.includes('api-sports.io') || url.includes('apifootball')) return <Badge tone="gold">api-football (white bg)</Badge>;
  return <Badge tone="neutral">Other</Badge>;
}
