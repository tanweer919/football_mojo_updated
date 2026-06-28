'use client';

import { useEffect, useState } from 'react';

/**
 * Kick-off time auto-localized to the visitor's timezone (client-side, so the
 * static/ISR HTML stays cacheable). SSR renders a stable UTC fallback to avoid
 * hydration mismatch + layout shift; the client upgrades it to local time.
 */
export function KickoffTime({ iso, withDate = false }: { iso: string; withDate?: boolean }) {
  const utcFallback = formatUtc(iso, withDate);
  const [label, setLabel] = useState(utcFallback);

  useEffect(() => {
    try {
      const d = new Date(iso);
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
      const opts: Intl.DateTimeFormatOptions = withDate
        ? { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZoneName: 'short' }
        : { hour: '2-digit', minute: '2-digit', timeZoneName: 'short' };
      setLabel(new Intl.DateTimeFormat(undefined, { ...opts, timeZone: tz }).format(d));
    } catch {
      /* keep UTC fallback */
    }
  }, [iso, withDate]);

  return <time dateTime={iso} suppressHydrationWarning>{label}</time>;
}

function formatUtc(iso: string, withDate: boolean): string {
  const d = new Date(iso);
  const opts: Intl.DateTimeFormatOptions = withDate
    ? { weekday: 'short', day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit', timeZone: 'UTC' }
    : { hour: '2-digit', minute: '2-digit', timeZone: 'UTC' };
  return `${new Intl.DateTimeFormat('en-GB', opts).format(d)} UTC`;
}
