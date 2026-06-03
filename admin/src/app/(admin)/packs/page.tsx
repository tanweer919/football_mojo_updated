import { apiServer } from '@/lib/api-server';
import { Topbar } from '@/components/topbar';
import { PacksManager, type Bundle } from './manager';

export const dynamic = 'force-dynamic';

interface Me { role: string; }

export default async function PacksPage() {
  const [me, bundles] = await Promise.all([
    apiServer<Me>('/admin/me'),
    apiServer<Bundle[]>('/admin/bundles'),
  ]);

  return (
    <>
      <Topbar title="Card Packs" role={me.role} />
      <div className="p-6">
        <PacksManager initial={bundles} />
      </div>
    </>
  );
}
