'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Field, Input, Select, Button, Panel, SectionHead, Badge } from '@/components/ui';
import { api } from '@/lib/api-client';

type CardRarity = 'COMMON' | 'UNCOMMON' | 'RARE' | 'EPIC' | 'LEGENDARY' | 'ICONIC';
const RARITIES: CardRarity[] = ['COMMON', 'UNCOMMON', 'RARE', 'EPIC', 'LEGENDARY', 'ICONIC'];

interface TemplateValues {
  id: string;
  edition: string;
  rarity: CardRarity;
  totalSupply: number;
  artUrl: string;
  frameStyle: string;
  giftableOnly: boolean;
  purchasable: boolean;
  gemPrice: string;
}

/**
 * Card template editor — controlled form, mutations via the backend admin
 * proxy. `mintedCount` is read-only (server-side counter, broken if edited
 * directly); the backend also rejects totalSupply < mintedCount, so we
 * mirror the constraint client-side as a hint.
 */
export function CardEditForm({
  template,
  mintedCount,
  playerPhotoUrl,
}: {
  template: TemplateValues;
  mintedCount: number;
  playerPhotoUrl: string | null;
}) {
  const [values, setValues] = useState(template);
  const [savedAt, setSavedAt] = useState<Date | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const router = useRouter();

  const dirty =
    values.edition !== template.edition ||
    values.rarity !== template.rarity ||
    values.totalSupply !== template.totalSupply ||
    values.artUrl !== template.artUrl ||
    values.frameStyle !== template.frameStyle ||
    values.giftableOnly !== template.giftableOnly ||
    values.purchasable !== template.purchasable ||
    values.gemPrice !== template.gemPrice;

  function set<K extends keyof TemplateValues>(k: K, v: TemplateValues[K]) {
    setValues((p) => ({ ...p, [k]: v }));
    setError(null);
  }

  function onSave() {
    setError(null);
    startTransition(async () => {
      try {
        const gemPriceN = values.gemPrice.trim();
        const gemPrice = gemPriceN === '' ? null : Number.parseInt(gemPriceN, 10);
        if (gemPrice !== null && (!Number.isFinite(gemPrice) || gemPrice < 0)) {
          throw new Error('Gem price must be a non-negative whole number.');
        }
        await api(`/cards/${values.id}`, {
          method: 'PATCH',
          body: JSON.stringify({
            edition: values.edition.trim(),
            rarity: values.rarity,
            totalSupply: Number(values.totalSupply),
            artUrl: values.artUrl.trim(),
            frameStyle: values.frameStyle.trim() || 'base',
            giftableOnly: values.giftableOnly,
            purchasable: values.purchasable,
            gemPrice,
          }),
        });
        setSavedAt(new Date());
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  return (
    <Panel>
      <SectionHead
        eyebrow="Template"
        title="Card metadata"
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
        <Field label="Edition" hint="Slug — e.g. WC2026-BASE, EPL-2025">
          <Input value={values.edition} onChange={(e) => set('edition', e.target.value)} />
        </Field>
        <Field label="Rarity">
          <Select value={values.rarity} onChange={(e) => set('rarity', e.target.value as CardRarity)}>
            {RARITIES.map((r) => <option key={r} value={r}>{r}</option>)}
          </Select>
        </Field>
        <Field label="Total supply" hint={`Cannot go below ${mintedCount} (already minted).`}>
          <Input
            type="number"
            min={mintedCount}
            value={values.totalSupply}
            onChange={(e) => set('totalSupply', Number.parseInt(e.target.value, 10) || 0)}
          />
        </Field>
        <Field label="Frame style" hint="base · holographic · trophy">
          <Input value={values.frameStyle} onChange={(e) => set('frameStyle', e.target.value)} />
        </Field>
      </div>

      <div className="mt-6 pt-6 border-t border-border">
        <Field label="Card art URL" hint="Falls back to the player's photo if blank. Saving the linked Player photo cascades here automatically.">
          <Input
            value={values.artUrl}
            onChange={(e) => set('artUrl', e.target.value)}
            placeholder={playerPhotoUrl ?? 'https://…'}
            className="font-mono text-xs"
          />
        </Field>
        {playerPhotoUrl && values.artUrl !== playerPhotoUrl && (
          <div className="mt-2 text-[11px] text-fg-muted2 flex items-center gap-2">
            <span>Out of sync with player photo.</span>
            <button
              type="button"
              className="text-gold hover:underline"
              onClick={() => set('artUrl', playerPhotoUrl)}
            >
              Use player photo →
            </button>
          </div>
        )}
      </div>

      <div className="mt-6 pt-6 border-t border-border grid grid-cols-1 md:grid-cols-2 gap-4">
        <label className="flex items-start gap-3 p-3 rounded-md bg-surface-2 border border-border cursor-pointer hover:border-gold/30">
          <input type="checkbox" checked={values.giftableOnly} onChange={(e) => set('giftableOnly', e.target.checked)} className="mt-0.5" />
          <div>
            <div className="font-bold text-sm">Giftable only</div>
            <div className="text-xs text-fg-muted mt-0.5">Earned/airdropped only. Never purchasable.</div>
          </div>
        </label>
        <label className="flex items-start gap-3 p-3 rounded-md bg-surface-2 border border-border cursor-pointer hover:border-gold/30">
          <input type="checkbox" checked={values.purchasable} onChange={(e) => set('purchasable', e.target.checked)} className="mt-0.5" />
          <div>
            <div className="font-bold text-sm">Purchasable</div>
            <div className="text-xs text-fg-muted mt-0.5">Buyable with gems for a fixed price.</div>
          </div>
        </label>
      </div>

      {values.purchasable && (
        <Field label="Gem price" className="mt-4" hint="Required when 'Purchasable' is on.">
          <Input
            type="number"
            min={0}
            value={values.gemPrice}
            onChange={(e) => set('gemPrice', e.target.value.replace(/[^\d]/g, ''))}
            placeholder="e.g. 250"
            className="max-w-xs"
          />
        </Field>
      )}

      {error && (
        <div className="mt-4 p-3 rounded-md bg-live/10 border border-live/30 text-live text-xs">
          {error}
        </div>
      )}

      <div className="mt-6 pt-5 border-t border-border flex items-center justify-end gap-3">
        <Button type="button" variant="ghost" onClick={() => setValues(template)} disabled={!dirty || pending}>
          Reset
        </Button>
        <Button type="button" variant="gold" onClick={onSave} disabled={!dirty || pending}>
          {pending ? 'Saving…' : 'Save changes'}
        </Button>
      </div>
    </Panel>
  );
}
