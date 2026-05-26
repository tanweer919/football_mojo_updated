'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Field, Input, Button, Panel, SectionHead, Badge } from '@/components/ui';
import { api } from '@/lib/api-client';

interface TeamValues {
  id: string;
  name: string;
  shortName: string;
  countryCode: string;
  crestUrl: string;
  primaryColor: string;
}

export function TeamEditForm({ team }: { team: TeamValues }) {
  const [values, setValues] = useState(team);
  const [savedAt, setSavedAt] = useState<Date | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const router = useRouter();

  const dirty =
    values.name !== team.name ||
    values.shortName !== team.shortName ||
    values.countryCode !== team.countryCode ||
    values.crestUrl !== team.crestUrl ||
    values.primaryColor !== team.primaryColor;

  function set<K extends keyof TeamValues>(k: K, v: TeamValues[K]) {
    setValues((p) => ({ ...p, [k]: v }));
    setError(null);
  }

  function onSave() {
    setError(null);
    startTransition(async () => {
      try {
        await api(`/teams/${values.id}`, {
          method: 'PATCH',
          body: JSON.stringify({
            name: values.name,
            shortName: values.shortName,
            countryCode: values.countryCode || null,
            crestUrl: values.crestUrl || null,
            primaryColor: values.primaryColor || null,
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
        eyebrow="Team record"
        title="Identity"
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
        <Field label="Name" className="md:col-span-2">
          <Input value={values.name} onChange={(e) => set('name', e.target.value)} />
        </Field>
        <Field label="Short name" hint="3-letter display abbreviation.">
          <Input value={values.shortName} onChange={(e) => set('shortName', e.target.value)} />
        </Field>
        <Field label="Country code" hint="ISO 3166 alpha-3 (GBR, ESP, BRA).">
          <Input
            value={values.countryCode}
            onChange={(e) => set('countryCode', e.target.value.toUpperCase().slice(0, 3))}
            className="font-mono"
          />
        </Field>
        <Field label="Crest URL" className="md:col-span-2" hint="Square PNG with transparent background looks best.">
          <Input
            value={values.crestUrl}
            onChange={(e) => set('crestUrl', e.target.value)}
            className="font-mono text-xs"
            placeholder="https://…"
          />
        </Field>
        <Field label="Primary colour" hint="Hex like #C8102E — used as the team accent.">
          <div className="flex items-center gap-2">
            <Input
              value={values.primaryColor}
              onChange={(e) => set('primaryColor', e.target.value)}
              className="font-mono"
              placeholder="#C8102E"
            />
            <div
              className="w-10 h-10 rounded-md border border-border shrink-0"
              style={{ background: /^#[0-9a-f]{6}$/i.test(values.primaryColor) ? values.primaryColor : 'transparent' }}
            />
          </div>
        </Field>
      </div>

      {error && (
        <div className="mt-4 p-3 rounded-md bg-live/10 border border-live/30 text-live text-xs">
          {error}
        </div>
      )}

      <div className="mt-6 pt-5 border-t border-border flex items-center justify-end gap-3">
        <Button type="button" variant="ghost" onClick={() => setValues(team)} disabled={!dirty || pending}>
          Reset
        </Button>
        <Button type="button" variant="gold" onClick={onSave} disabled={!dirty || pending}>
          {pending ? 'Saving…' : 'Save changes'}
        </Button>
      </div>
    </Panel>
  );
}
