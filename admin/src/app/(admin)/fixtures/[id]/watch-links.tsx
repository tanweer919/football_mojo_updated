'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api-client';
import { Panel, SectionHead, Field, Input, Button, Badge, Empty } from '@/components/ui';

export interface WatchLink {
  id: string;
  name: string;
  url: string | null;
  countryCode: string | null;
  countryName: string | null;
  source: 'ADMIN' | 'SCRAPER';
  position: number;
}

type Draft = {
  name: string;
  url: string;
  countryCode: string;
  countryName: string;
  position: string;
};

const EMPTY: Draft = { name: '', url: '', countryCode: '', countryName: '', position: '0' };

export function WatchLinksEditor({ matchId, initial }: { matchId: string; initial: WatchLink[] }) {
  // `editing`: null = closed, 'new' = add form, or a link id being edited.
  const [editing, setEditing] = useState<string | 'new' | null>(null);
  const [draft, setDraft] = useState<Draft>(EMPTY);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const router = useRouter();

  function set<K extends keyof Draft>(k: K, v: string) {
    setDraft((p) => ({ ...p, [k]: v }));
    setError(null);
  }

  function openNew() {
    setDraft(EMPTY);
    setEditing('new');
    setError(null);
  }

  function openEdit(l: WatchLink) {
    setDraft({
      name: l.name,
      url: l.url ?? '',
      countryCode: l.countryCode ?? '',
      countryName: l.countryName ?? '',
      position: String(l.position),
    });
    setEditing(l.id);
    setError(null);
  }

  function save() {
    if (!draft.name.trim()) { setError('Name is required.'); return; }
    const body = JSON.stringify({
      name: draft.name.trim(),
      url: draft.url.trim() || null,
      countryCode: draft.countryCode.trim().toUpperCase() || null,
      countryName: draft.countryName.trim() || null,
      position: Number.parseInt(draft.position, 10) || 0,
    });
    startTransition(async () => {
      try {
        if (editing === 'new') {
          await api(`/fixtures/${matchId}/watch-links`, { method: 'POST', body });
        } else {
          await api(`/fixtures/watch-links/${editing}`, { method: 'PATCH', body });
        }
        setEditing(null);
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  function remove(l: WatchLink) {
    if (!confirm(`Delete watch link "${l.name}"?`)) return;
    startTransition(async () => {
      try {
        await api(`/fixtures/watch-links/${l.id}`, { method: 'DELETE' });
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  return (
    <Panel>
      <SectionHead
        eyebrow="Where to watch"
        title="Watch links"
        action={editing === null && <Button variant="gold" size="sm" onClick={openNew}>+ Add link</Button>}
      />

      {editing !== null && (
        <div className="mb-5 p-4 rounded-lg border border-gold/30 bg-surface-1 space-y-4">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <Field label="Name" hint="Channel / broadcaster, e.g. “Sky Sports”">
              <Input value={draft.name} onChange={(e) => set('name', e.target.value)} placeholder="Sky Sports" autoFocus />
            </Field>
            <Field label="Watch link (URL)" hint="Optional — leave blank for TV-only">
              <Input value={draft.url} onChange={(e) => set('url', e.target.value)} placeholder="https://…" />
            </Field>
            <Field label="Country code" hint="ISO-2, e.g. GB. Blank = worldwide">
              <Input value={draft.countryCode} onChange={(e) => set('countryCode', e.target.value)} placeholder="GB" maxLength={2} />
            </Field>
            <Field label="Country name" hint="Optional display name">
              <Input value={draft.countryName} onChange={(e) => set('countryName', e.target.value)} placeholder="United Kingdom" />
            </Field>
          </div>
          {error && <div className="p-3 rounded-md bg-live/10 border border-live/30 text-live text-xs">{error}</div>}
          <div className="flex items-center justify-end gap-3">
            <Button variant="ghost" onClick={() => { setEditing(null); setError(null); }} disabled={pending}>Cancel</Button>
            <Button variant="gold" onClick={save} disabled={pending}>{pending ? 'Saving…' : 'Save link'}</Button>
          </div>
        </div>
      )}

      {initial.length === 0 ? (
        <Empty title="No watch links yet" hint="Add one above, or run the scraper ingest to bulk-fill." />
      ) : (
        <div className="divide-y divide-border">
          {initial.map((l) => (
            <div key={l.id} className="flex items-center gap-3 py-3">
              <div className="w-10 text-center font-mono text-xs text-fg-muted2">
                {l.countryCode ?? '🌐'}
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-fg font-medium truncate">{l.name}</div>
                {l.url
                  ? <a href={l.url} target="_blank" rel="noreferrer" className="text-xs text-info hover:underline truncate block">{l.url}</a>
                  : <div className="text-xs text-fg-muted2">No link</div>}
              </div>
              <Badge tone={l.source === 'ADMIN' ? 'gold' : 'neutral'}>{l.source}</Badge>
              <Button variant="ghost" size="sm" onClick={() => openEdit(l)} disabled={pending}>Edit</Button>
              <Button variant="danger" size="sm" onClick={() => remove(l)} disabled={pending}>Delete</Button>
            </div>
          ))}
        </div>
      )}
    </Panel>
  );
}
