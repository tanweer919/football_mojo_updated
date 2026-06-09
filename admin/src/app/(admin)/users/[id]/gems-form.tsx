'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Button, Field, Input } from '@/components/ui';
import { api } from '@/lib/api-client';

/**
 * Set a user's gem balance to an exact value. Routed through
 * `PATCH /admin/users/:id/gems`, which adjusts via the gem ledger (audited).
 * Shows the delta so the admin sees exactly what will be credited/debited.
 */
export function GemsEditor({ userId, currentGems }: { userId: string; currentGems: number }) {
  const [balance, setBalance] = useState(String(currentGems));
  const [reason, setReason] = useState('');
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [savedAt, setSavedAt] = useState<Date | null>(null);
  const router = useRouter();

  const target = Number.parseInt(balance, 10);
  const valid = Number.isFinite(target) && target >= 0;
  const delta = valid ? target - currentGems : 0;
  const dirty = valid && delta !== 0;

  function onSave() {
    setError(null);
    if (!valid) {
      setError('Enter a whole number ≥ 0.');
      return;
    }
    startTransition(async () => {
      try {
        await api(`/users/${userId}/gems`, {
          method: 'PATCH',
          body: JSON.stringify({ balance: target, reason: reason.trim() || undefined }),
        });
        setSavedAt(new Date());
        setReason('');
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  return (
    <div className="grid grid-cols-1 sm:grid-cols-[160px_1fr_auto] gap-4 items-end">
      <Field label="New gem balance" hint={`Current: ${currentGems.toLocaleString()}`}>
        <Input
          type="number"
          min={0}
          value={balance}
          onChange={(e) => setBalance(e.target.value.replace(/[^\d]/g, ''))}
          className="font-mono"
        />
      </Field>
      <Field label="Reason (optional)" hint="Logged on the gem ledger entry.">
        <Input
          value={reason}
          onChange={(e) => setReason(e.target.value)}
          placeholder="e.g. compensation for failed purchase"
          maxLength={140}
        />
      </Field>
      <div className="flex flex-col gap-1.5">
        {dirty && (
          <span className={`text-xs font-mono ${delta > 0 ? 'text-pitch' : 'text-live'}`}>
            {delta > 0 ? '+' : ''}{delta.toLocaleString()} gems
          </span>
        )}
        <Button variant="gold" onClick={onSave} disabled={!dirty || pending}>
          {pending ? 'Saving…' : 'Set balance'}
        </Button>
      </div>

      {(error || savedAt) && (
        <div className="sm:col-span-3">
          {error && <span className="text-xs text-live">{error}</span>}
          {!error && savedAt && (
            <span className="text-xs font-mono text-pitch">Balance updated {savedAt.toLocaleTimeString()}</span>
          )}
        </div>
      )}
    </div>
  );
}
