'use client';

import { useEffect, useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { api } from '@/lib/api-client';
import { Button, Field, Input, Textarea, Panel, SectionHead, Badge, Empty } from '@/components/ui';

// ─── Types (mirror the backend admin/bundles payloads) ─────────────────────

export interface BundleCard {
  templateId: string;
  rarity: string;
  edition: string;
  artUrl: string;
  playerName: string | null;
  singlePrice: number | null;
}
export interface Bundle {
  id: string;
  name: string;
  description: string | null;
  gemPrice: number;
  artUrl: string | null;
  active: boolean;
  sortOrder: number;
  cards: BundleCard[];
  cardCount: number;
  singleTotal: number;
  saving: number;
}

interface CardSearchRow {
  id: string;
  edition: string;
  rarity: string;
  player: { id: string; name: string } | null;
}

interface SelectedCard {
  templateId: string;
  label: string;
  rarity: string;
}

// ─── Manager (list + editor) ────────────────────────────────────────────────

export function PacksManager({ initial }: { initial: Bundle[] }) {
  // `null` = nothing open, 'new' = create form, Bundle = editing that one.
  const [editing, setEditing] = useState<Bundle | 'new' | null>(null);

  return (
    <div className="space-y-5">
      <SectionHead
        eyebrow="Transparent bundles"
        title="Card Packs"
        action={
          editing == null ? (
            <Button variant="gold" onClick={() => setEditing('new')}>+ New pack</Button>
          ) : null
        }
      />

      {editing != null && (
        <BundleEditor
          bundle={editing === 'new' ? null : editing}
          onClose={() => setEditing(null)}
        />
      )}

      {initial.length === 0 && editing == null ? (
        <Panel>
          <Empty
            title="No packs yet"
            hint="Create a pack: name it, set a gem price, and add the exact cards buyers receive."
          />
        </Panel>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-4">
          {initial.map((b) => (
            <BundleCardView key={b.id} bundle={b} onEdit={() => setEditing(b)} />
          ))}
        </div>
      )}
    </div>
  );
}

// ─── A single bundle summary card ────────────────────────────────────────────

function BundleCardView({ bundle, onEdit }: { bundle: Bundle; onEdit: () => void }) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  function onDelete() {
    if (!confirm(`Delete pack “${bundle.name}”? This cannot be undone.`)) return;
    setError(null);
    startTransition(async () => {
      try {
        await api(`/bundles/${bundle.id}`, { method: 'DELETE' });
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  return (
    <Panel>
      <div className="flex items-start justify-between gap-3">
        <div>
          <div className="flex items-center gap-2">
            <h3 className="font-bold text-fg">{bundle.name}</h3>
            {bundle.active ? <Badge tone="green">Active</Badge> : <Badge tone="red">Hidden</Badge>}
          </div>
          {bundle.description && (
            <p className="text-xs text-fg-muted mt-1 max-w-md">{bundle.description}</p>
          )}
        </div>
        <div className="text-right shrink-0">
          <div className="font-mono font-bold text-gold tabular-nums">{bundle.gemPrice}💎</div>
          {bundle.saving > 0 && (
            <div className="text-[10px] font-mono text-pitch">save {bundle.saving}</div>
          )}
        </div>
      </div>

      <div className="mt-3 flex flex-wrap gap-1.5">
        {bundle.cards.map((c) => (
          <span
            key={c.templateId}
            className="inline-flex items-center gap-1.5 px-2 py-1 rounded-md bg-surface-2 border border-border text-xs"
            title={c.edition}
          >
            <Badge tone={rarityTone(c.rarity)}>{c.rarity.slice(0, 3)}</Badge>
            <span className="text-fg-soft">{c.playerName ?? c.edition}</span>
          </span>
        ))}
      </div>

      {error && <div className="mt-3 text-xs text-live">{error}</div>}

      <div className="mt-4 pt-3 border-t border-border flex items-center justify-between">
        <span className="text-[11px] font-mono text-fg-muted2">
          {bundle.cardCount} cards · order {bundle.sortOrder}
        </span>
        <div className="flex gap-2">
          <Button size="sm" variant="danger" onClick={onDelete} disabled={pending}>
            {pending ? 'Deleting…' : 'Delete'}
          </Button>
          <Button size="sm" variant="soft" onClick={onEdit}>Edit</Button>
        </div>
      </div>
    </Panel>
  );
}

// ─── Create / edit form ───────────────────────────────────────────────────

function BundleEditor({ bundle, onClose }: { bundle: Bundle | null; onClose: () => void }) {
  const isNew = bundle == null;
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);

  const [name, setName] = useState(bundle?.name ?? '');
  const [description, setDescription] = useState(bundle?.description ?? '');
  const [gemPrice, setGemPrice] = useState(bundle ? String(bundle.gemPrice) : '');
  const [sortOrder, setSortOrder] = useState(bundle ? String(bundle.sortOrder) : '0');
  const [active, setActive] = useState(bundle?.active ?? true);
  const [selected, setSelected] = useState<SelectedCard[]>(
    bundle?.cards.map((c) => ({
      templateId: c.templateId,
      label: c.playerName ?? c.edition,
      rarity: c.rarity,
    })) ?? [],
  );

  function addCard(c: CardSearchRow) {
    if (selected.some((s) => s.templateId === c.id)) return;
    setSelected((p) => [
      ...p,
      { templateId: c.id, label: c.player?.name ?? c.edition, rarity: c.rarity },
    ]);
  }
  function removeCard(id: string) {
    setSelected((p) => p.filter((s) => s.templateId !== id));
  }

  function onSave() {
    setError(null);
    const price = Number.parseInt(gemPrice, 10);
    if (!name.trim()) { setError('Give the pack a name.'); return; }
    if (!Number.isFinite(price) || price <= 0) { setError('Gem price must be a positive whole number.'); return; }
    if (selected.length === 0) { setError('Add at least one card to the pack.'); return; }

    startTransition(async () => {
      try {
        await api(isNew ? '/bundles' : `/bundles/${bundle!.id}`, {
          method: isNew ? 'POST' : 'PATCH',
          body: JSON.stringify({
            name: name.trim(),
            description: description.trim() || undefined,
            gemPrice: price,
            active,
            sortOrder: Number.parseInt(sortOrder, 10) || 0,
            templateIds: selected.map((s) => s.templateId),
          }),
        });
        router.refresh();
        onClose();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  return (
    <Panel className="border-gold/30">
      <SectionHead
        eyebrow={isNew ? 'New pack' : 'Editing'}
        title={isNew ? 'Create a card pack' : name || 'Edit pack'}
        action={<Button variant="ghost" onClick={onClose}>Close</Button>}
      />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <Field label="Name" className="md:col-span-2">
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Galácticos" />
        </Field>
        <Field label="Gem price" hint="What the buyer pays.">
          <Input
            type="number"
            min={1}
            value={gemPrice}
            onChange={(e) => setGemPrice(e.target.value.replace(/[^\d]/g, ''))}
            placeholder="e.g. 850"
          />
        </Field>
      </div>

      <Field label="Description" className="mt-4" hint="Shown under the pack name in the shop.">
        <Textarea value={description} onChange={(e) => setDescription(e.target.value)} placeholder="One line on what's inside." />
      </Field>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
        <Field label="Sort order" hint="Lower shows first.">
          <Input
            type="number"
            value={sortOrder}
            onChange={(e) => setSortOrder(e.target.value.replace(/[^\d-]/g, ''))}
          />
        </Field>
        <label className="flex items-center gap-3 p-3 rounded-md bg-surface-2 border border-border cursor-pointer hover:border-gold/30 self-end">
          <input type="checkbox" checked={active} onChange={(e) => setActive(e.target.checked)} />
          <div>
            <div className="font-bold text-sm">Active</div>
            <div className="text-xs text-fg-muted mt-0.5">Visible in the shop.</div>
          </div>
        </label>
      </div>

      <div className="mt-6 pt-5 border-t border-border">
        <div className="eyebrow-gold mb-2">Cards in this pack ({selected.length})</div>
        {selected.length === 0 ? (
          <div className="text-xs text-fg-muted2 mb-3">No cards yet — search below and click to add.</div>
        ) : (
          <div className="flex flex-wrap gap-1.5 mb-3">
            {selected.map((s) => (
              <span key={s.templateId} className="inline-flex items-center gap-1.5 px-2 py-1 rounded-md bg-surface-2 border border-border text-xs">
                <Badge tone={rarityTone(s.rarity)}>{s.rarity.slice(0, 3)}</Badge>
                <span className="text-fg-soft">{s.label}</span>
                <button
                  type="button"
                  onClick={() => removeCard(s.templateId)}
                  className="text-fg-muted hover:text-live ml-0.5"
                  aria-label="Remove"
                >
                  ×
                </button>
              </span>
            ))}
          </div>
        )}
        <CardPicker selectedIds={selected.map((s) => s.templateId)} onAdd={addCard} />
      </div>

      {error && (
        <div className="mt-4 p-3 rounded-md bg-live/10 border border-live/30 text-live text-xs">{error}</div>
      )}

      <div className="mt-6 pt-5 border-t border-border flex items-center justify-end gap-3">
        <Button variant="ghost" onClick={onClose} disabled={pending}>Cancel</Button>
        <Button variant="gold" onClick={onSave} disabled={pending}>
          {pending ? 'Saving…' : isNew ? 'Create pack' : 'Save changes'}
        </Button>
      </div>
    </Panel>
  );
}

// ─── Card search/picker ──────────────────────────────────────────────────

function CardPicker({ selectedIds, onAdd }: { selectedIds: string[]; onAdd: (c: CardSearchRow) => void }) {
  const [q, setQ] = useState('');
  const [rows, setRows] = useState<CardSearchRow[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const term = q.trim();
    if (!term) { setRows([]); return; }
    let cancelled = false;
    setLoading(true);
    const t = setTimeout(async () => {
      try {
        const data = await api<{ rows: CardSearchRow[] }>(
          `/cards?q=${encodeURIComponent(term)}&pageSize=20`,
        );
        if (!cancelled) setRows(data.rows);
      } catch {
        if (!cancelled) setRows([]);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }, 300);
    return () => { cancelled = true; clearTimeout(t); };
  }, [q]);

  return (
    <div>
      <Input value={q} onChange={(e) => setQ(e.target.value)} placeholder="Search cards by player name…" />
      {q.trim() !== '' && (
        <div className="mt-2 max-h-64 overflow-y-auto rounded-md border border-border divide-y divide-border">
          {loading ? (
            <div className="px-3 py-3 text-xs text-fg-muted">Searching…</div>
          ) : rows.length === 0 ? (
            <div className="px-3 py-3 text-xs text-fg-muted">No cards match.</div>
          ) : (
            rows.map((c) => {
              const added = selectedIds.includes(c.id);
              return (
                <button
                  key={c.id}
                  type="button"
                  disabled={added}
                  onClick={() => onAdd(c)}
                  className="w-full flex items-center gap-2 px-3 py-2 text-left hover:bg-surface-2/60 disabled:opacity-40 disabled:cursor-not-allowed"
                >
                  <Badge tone={rarityTone(c.rarity)}>{c.rarity.slice(0, 3)}</Badge>
                  <span className="text-sm text-fg flex-1">{c.player?.name ?? '— no player —'}</span>
                  <span className="text-[10px] font-mono text-fg-muted2">{c.edition}</span>
                  <span className="text-xs text-gold font-semibold">{added ? 'Added' : '+ Add'}</span>
                </button>
              );
            })
          )}
        </div>
      )}
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
