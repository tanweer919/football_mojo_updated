import { apiServer } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { ChannelsManager, type ChannelOverride, type MissingChannel } from './manager';

export const dynamic = 'force-dynamic';

interface Me { role: string; }

export default async function ChannelsPage() {
  const [me, data] = await Promise.all([
    apiServer<Me>('/admin/me'),
    apiServer<{ overrides: ChannelOverride[]; missing: MissingChannel[] }>('/admin/channels'),
  ]);

  return (
    <>
      <Topbar title="Channels" role={me.role} />
      <div className="p-6 max-w-4xl space-y-5">
        <p className="text-sm text-fg-muted">
          Set a watch link for a broadcaster <span className="text-fg-soft">by name</span> — it applies
          to <span className="text-fg-soft">every fixture</span> that channel appears in, overriding the
          scraped link. Fix “Fox Sports 1” once instead of per match.
        </p>
        <ChannelsManager overrides={data.overrides} missing={data.missing} />
      </div>
    </>
  );
}
