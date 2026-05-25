'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Button, Select, Input } from '@/components/ui';
import { api } from '@/lib/api-client';

type UserRole = 'USER' | 'ADMIN' | 'SUPERADMIN';

/**
 * Per-row role control. Inline Select + Save — admins flip role frequently
 * enough that opening a modal would feel heavy. Calls `PATCH /admin/users/
 * :id/role` on the backend; the backend rejects self-demote with a clear
 * error code we surface here.
 */
export function UserRoleControls({
  userId,
  currentRole,
  isSelf,
}: {
  userId: string;
  currentRole: UserRole;
  isSelf: boolean;
}) {
  const [role, setRole] = useState<UserRole>(currentRole);
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();
  const dirty = role !== currentRole;

  function onSave() {
    setError(null);
    startTransition(async () => {
      try {
        await api(`/users/${userId}/role`, {
          method: 'PATCH',
          body: JSON.stringify({ role }),
        });
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
        setRole(currentRole);
      }
    });
  }

  return (
    <div className="flex items-center gap-2">
      <Select
        value={role}
        onChange={(e) => setRole(e.target.value as UserRole)}
        className="!h-8 !py-1 !text-xs !w-32"
        disabled={pending}
        title={isSelf ? 'Be careful — changing your own role can lock you out.' : ''}
      >
        <option value="USER">USER</option>
        <option value="ADMIN">ADMIN</option>
        <option value="SUPERADMIN">SUPERADMIN</option>
      </Select>
      <Button size="sm" variant={dirty ? 'gold' : 'ghost'} onClick={onSave} disabled={!dirty || pending}>
        {pending ? '…' : dirty ? 'Save' : 'OK'}
      </Button>
      {error && <span className="text-[10px] text-live ml-1">{error}</span>}
    </div>
  );
}

/**
 * SUPERADMIN-only "Invite admin" form. Calls `POST /admin/users/invite`
 * which either creates a new User row with role=ADMIN/SUPERADMIN or
 * promotes an existing email.
 */
export function InviteAdminForm() {
  const [email, setEmail] = useState('');
  const [asSuper, setAsSuper] = useState(false);
  const [busy, startTransition] = useTransition();
  const [result, setResult] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const router = useRouter();

  function submit(e: React.FormEvent) {
    e.preventDefault();
    setResult(null);
    setError(null);
    startTransition(async () => {
      try {
        const r = await api<{ id: string; created: boolean }>('/users/invite', {
          method: 'POST',
          body: JSON.stringify({ email, asSuper }),
        });
        setResult(
          r.created
            ? `✓ Created ${email} as ${asSuper ? 'SUPERADMIN' : 'ADMIN'}`
            : `✓ ${email} updated to ${asSuper ? 'SUPERADMIN' : 'ADMIN'}`,
        );
        setEmail('');
        router.refresh();
      } catch (e) {
        setError(e instanceof Error ? e.message : String(e));
      }
    });
  }

  return (
    <form onSubmit={submit} className="flex flex-wrap items-center gap-3">
      <Input
        type="email"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="someone@example.com"
        className="max-w-sm font-mono text-sm"
        disabled={busy}
      />
      <label className="flex items-center gap-2 text-sm text-fg-soft cursor-pointer">
        <input type="checkbox" checked={asSuper} onChange={(e) => setAsSuper(e.target.checked)} disabled={busy} />
        as SUPERADMIN
      </label>
      <Button type="submit" variant="gold" size="md" disabled={busy || !email.trim()}>
        {busy ? 'Inviting…' : 'Invite'}
      </Button>
      {result && <span className="text-xs font-mono text-pitch">{result}</span>}
      {error && <span className="text-xs text-live">{error}</span>}
    </form>
  );
}
