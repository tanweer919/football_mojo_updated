'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api-client';
import { Panel, SectionHead, Field, Input, Button, Badge, Empty } from '@/components/ui';

export interface ChannelOverride {
  id: string;
  name: string;
  url: string;
}
export interface MissingChannel {
  name: string;
  fixtures: number;
}

export function ChannelsManager({
  overrides,
  missing,
}: {
  overrides: ChannelOverride[];
  missing: MissingChannel[];
}) {
  // editing: null = closed, 'new' = add form, or an override id being edited.
  const [editing, setEditing] = useState<string | 'new' | null>(null);
  const [name, setName] = useState('');
  const [url, setUrl] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const router = useRouter();

  function openNew(prefillName = '') {
    setName(prefillName);
    setUrl('');
    setEditing('new');
    setError(null);
  }

  function openEdit(o: ChannelOverride) {
    setName(o.name);
    setUrl(o.url);
    setEditing(o.id);
    setError(null);
  }

  function save() {
    if (!name.trim() || !url.trim()) {
      setError('Both name and link are required.');
      return;
    }
    const body = JSON.stringify({ name: name.trim(), url: url.trim() });
    startTransition(async () => {
      try {
        if (editing === 'new') {
          await api('/channels', { method: 'POST', body });
        } else {
          await api(`/channels/${editing}`, { method: 'PATCH', body });
        }
        setEditing(null);
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  function remove(o: ChannelOverride) {
    if (!confirm(`Remove the link override for "${o.name}"?`)) return;
    startTransition(async () => {
      try {
        await api(`/channels/${o.id}`, { method: 'DELETE' });
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  return (
    <div className="space-y-5">
      <Panel>
        <SectionHead
          eyebrow="Overrides"
          title="Channel links"
          action={editing === null && <Button variant="gold" size="sm" onClick={() => openNew()}>+ Add channel</Button>}
        />

        {editing !== null && (
          <div className="mb-5 p-4 rounded-lg border border-gold/30 bg-surface-1 space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <Field label="Channel name" hint="Exactly as shown, e.g. “Fox Sports 1”">
                <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Fox Sports 1" autoFocus />
              </Field>
              <Field label="Watch link (URL)">
                <Input value={url} onChange={(e) => setUrl(e.target.value)} placeholder="https://…" />
              </Field>
            </div>
            {error && <div className="p-3 rounded-md bg-live/10 border border-live/30 text-live text-xs">{error}</div>}
            <div className="flex items-center justify-end gap-3">
              <Button variant="ghost" onClick={() => { setEditing(null); setError(null); }} disabled={pending}>Cancel</Button>
              <Button variant="gold" onClick={save} disabled={pending}>{pending ? 'Saving…' : 'Save'}</Button>
            </div>
          </div>
        )}

        {overrides.length === 0 ? (
          <Empty title="No channel overrides yet" hint="Add one above, or pick from the list below." />
        ) : (
          <div className="divide-y divide-border">
            {overrides.map((o) => (
              <div key={o.id} className="flex items-center gap-3 py-3">
                <div className="flex-1 min-w-0">
                  <div className="text-fg font-medium truncate">{o.name}</div>
                  <a href={o.url} target="_blank" rel="noreferrer" className="text-xs text-info hover:underline truncate block">{o.url}</a>
                </div>
                <Button variant="ghost" size="sm" onClick={() => openEdit(o)} disabled={pending}>Edit</Button>
                <Button variant="danger" size="sm" onClick={() => remove(o)} disabled={pending}>Delete</Button>
              </div>
            ))}
          </div>
        )}
      </Panel>

      <Panel>
        <SectionHead eyebrow="Needs a link" title={`Channels with no link (${missing.length})`} />
        {missing.length === 0 ? (
          <Empty title="All set" hint="Every channel currently has a link or an override." />
        ) : (
          <div className="divide-y divide-border">
            {missing.map((m) => (
              <div key={m.name} className="flex items-center gap-3 py-2.5">
                <div className="flex-1 min-w-0">
                  <span className="text-fg-soft text-sm truncate">{m.name}</span>
                </div>
                <Badge tone="neutral">{m.fixtures} {m.fixtures === 1 ? 'fixture' : 'fixtures'}</Badge>
                <Button variant="soft" size="sm" onClick={() => openNew(m.name)} disabled={pending}>Add link</Button>
              </div>
            ))}
          </div>
        )}
      </Panel>
    </div>
  );
}
