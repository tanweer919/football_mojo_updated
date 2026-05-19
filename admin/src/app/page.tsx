import { redirect } from 'next/navigation';

/**
 * Root `/` — middleware already handles unauth → /login. By the time the
 * request reaches this server component the user is a signed-in admin,
 * so we just route them at the dashboard.
 */
export default function RootPage() {
  redirect('/dashboard');
}
