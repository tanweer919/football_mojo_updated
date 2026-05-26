import { apiServer } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { Table, THead, TH, TR, TD, Input, Badge, Panel, SectionHead, Empty } from '@/components/ui';
import { UserRoleControls, InviteAdminForm } from './controls';

export const dynamic = 'force-dynamic';

const PAGE_SIZE = 30;

interface Me { id: string; role: 'USER' | 'ADMIN' | 'SUPERADMIN'; }
interface UserRow {
  id: string;
  email: string | null;
  displayName: string | null;
  userTag: string | null;
  role: 'USER' | 'ADMIN' | 'SUPERADMIN';
  photoUrl: string | null;
  createdAt: string;
}

export default async function UsersPage({
  searchParams,
}: {
  searchParams: { q?: string; role?: 'USER' | 'ADMIN' | 'SUPERADMIN'; page?: string };
}) {
  const q = (searchParams.q ?? '').trim();
  const role = searchParams.role;
  const page = Math.max(1, Number.parseInt(searchParams.page ?? '1', 10) || 1);

  const qs = new URLSearchParams();
  if (q) qs.set('q', q);
  if (role) qs.set('role', role);
  qs.set('page', String(page));
  qs.set('pageSize', String(PAGE_SIZE));

  const [me, data] = await Promise.all([
    apiServer<Me>('/admin/me'),
    apiServer<{ rows: UserRow[]; total: number; adminTotal: number }>(`/admin/users?${qs}`),
  ]);
  const isSuper = me.role === 'SUPERADMIN';
  const pageCount = Math.max(1, Math.ceil(data.total / PAGE_SIZE));

  return (
    <>
      <Topbar title="Users" role={me.role} />
      <div className="p-6 space-y-6 max-w-7xl">
        {isSuper && (
          <Panel>
            <SectionHead eyebrow="Privileged action" title="Invite an admin" />
            <p className="text-sm text-fg-muted mb-4 max-w-xl leading-relaxed">
              Creates an admin shell for an email that hasn&apos;t signed into the mobile app yet — or promotes an existing user. They&apos;ll be able to sign in with Google immediately.
            </p>
            <InviteAdminForm />
          </Panel>
        )}

        <form method="GET" className="flex flex-wrap items-center gap-3">
          <Input name="q" defaultValue={q} placeholder="Email, display name, or @tag…" className="max-w-sm" />
          <div className="flex gap-2">
            <FilterChip name="role" value="" active={!role} label="All" />
            <FilterChip name="role" value="USER" active={role === 'USER'} label="Users" />
            <FilterChip name="role" value="ADMIN" active={role === 'ADMIN'} label="Admins" />
            <FilterChip name="role" value="SUPERADMIN" active={role === 'SUPERADMIN'} label="Supers" />
          </div>
          <div className="ml-auto text-xs font-mono text-fg-muted">
            {data.total.toLocaleString()} match · {data.adminTotal} admin{data.adminTotal === 1 ? '' : 's'} total
          </div>
        </form>

        {data.rows.length === 0 ? (
          <div className="panel-strong"><Empty title="No users match" /></div>
        ) : (
          <Table>
            <THead>
              <TH>User</TH>
              <TH>Email</TH>
              <TH>Tag</TH>
              <TH>Role</TH>
              <TH>Joined</TH>
              <TH />
            </THead>
            <tbody>
              {data.rows.map((u) => {
                const isSelf = u.id === me.id;
                return (
                  <TR key={u.id}>
                    <TD>
                      <div className="font-medium text-fg">{u.displayName ?? '—'}</div>
                      <div className="text-[10px] font-mono text-fg-muted2">{u.id.slice(0, 16)}…</div>
                    </TD>
                    <TD className="text-fg-soft text-sm font-mono">{u.email ?? '—'}</TD>
                    <TD className="text-gold font-mono text-sm">{u.userTag ? `@${u.userTag}` : '—'}</TD>
                    <TD><Badge tone={roleTone(u.role)}>{u.role}</Badge>{isSelf && <span className="ml-2 text-[9px] font-mono uppercase text-fg-muted2">you</span>}</TD>
                    <TD className="text-fg-muted text-xs font-mono">{u.createdAt.slice(0, 10)}</TD>
                    <TD>
                      {isSuper ? (
                        <UserRoleControls userId={u.id} currentRole={u.role} isSelf={isSelf} />
                      ) : (
                        <span className="text-[11px] text-fg-muted2">Read-only</span>
                      )}
                    </TD>
                  </TR>
                );
              })}
            </tbody>
          </Table>
        )}

        {pageCount > 1 && (
          <div className="flex items-center justify-between text-sm">
            <div className="text-fg-muted font-mono">Page {page} of {pageCount}</div>
            <div className="flex gap-2">
              <PageLink page={page - 1} q={q} role={role} disabled={page <= 1}>← Prev</PageLink>
              <PageLink page={page + 1} q={q} role={role} disabled={page >= pageCount}>Next →</PageLink>
            </div>
          </div>
        )}
      </div>
    </>
  );
}

function FilterChip({ name, value, label, active }: { name: string; value: string; label: string; active: boolean }) {
  return (
    <button
      type="submit"
      name={name}
      value={value}
      className={
        active
          ? 'h-9 px-3 rounded-md text-xs font-bold bg-gold/15 text-gold border border-gold/30'
          : 'h-9 px-3 rounded-md text-xs font-bold bg-surface-1 text-fg-soft border border-border hover:border-gold/30'
      }
    >
      {label}
    </button>
  );
}

function PageLink({ page, q, role, disabled, children }: { page: number; q: string; role?: string; disabled: boolean; children: React.ReactNode }) {
  if (disabled) return <span className="px-3 py-1.5 text-fg-muted2 text-xs">{children}</span>;
  const sp = new URLSearchParams();
  if (q) sp.set('q', q);
  if (role) sp.set('role', role);
  sp.set('page', String(page));
  return (
    <a href={`/users?${sp.toString()}`} className="px-3 py-1.5 rounded-md bg-surface-2 hover:bg-surface-3 text-fg text-xs font-bold border border-border">
      {children}
    </a>
  );
}

function roleTone(r: string): 'gold' | 'blue' | 'neutral' {
  if (r === 'SUPERADMIN') return 'gold';
  if (r === 'ADMIN') return 'blue';
  return 'neutral';
}
