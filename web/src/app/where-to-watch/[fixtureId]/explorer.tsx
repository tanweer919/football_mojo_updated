'use client';

import { useMemo, useState } from 'react';
import { flagEmoji, type CountryBroadcast } from '@/lib/api';

/**
 * Interactive country browser layered on top of the server-rendered list.
 * Detects the visitor's country from the browser locale (no permission) and
 * pins it on top; everything else is searchable.
 */
export function BroadcastExplorer({ countries }: { countries: CountryBroadcast[] }) {
  const [query, setQuery] = useState('');

  const myCountry = useMemo(() => {
    if (typeof navigator === 'undefined') return null;
    const tag = navigator.language || (navigator.languages && navigator.languages[0]);
    const region = tag?.split('-')[1];
    return region ? region.toUpperCase() : null;
  }, []);

  const { pinned, rest } = useMemo(() => {
    const q = query.trim().toLowerCase();
    const filtered = q
      ? countries.filter(
          (c) => c.countryName.toLowerCase().includes(q) || c.country.toLowerCase().includes(q),
        )
      : countries;
    const pinned = myCountry ? filtered.find((c) => c.country === myCountry) ?? null : null;
    const rest = filtered.filter((c) => c !== pinned);
    return { pinned, rest };
  }, [countries, query, myCountry]);

  return (
    <div>
      <div className="sticky top-2 z-10 mb-6">
        <input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search 200+ countries…"
          className="w-full rounded-full border border-border bg-surface-1/90 px-5 py-3 text-sm text-fg backdrop-blur placeholder:text-fg-muted2 focus:border-gold/50 focus:outline-none focus:ring-2 focus:ring-gold/15"
        />
      </div>

      {pinned && (
        <div className="mb-6">
          <p className="eyebrow mb-2">Your region</p>
          <CountryCard country={pinned} highlight />
        </div>
      )}

      {rest.length === 0 && !pinned ? (
        <p className="panel p-8 text-center text-fg-muted">No countries match “{query}”.</p>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          {rest.map((c) => (
            <CountryCard key={c.country || c.countryName} country={c} />
          ))}
        </div>
      )}
    </div>
  );
}

function CountryCard({ country, highlight = false }: { country: CountryBroadcast; highlight?: boolean }) {
  return (
    <div
      className={`panel p-4 ${highlight ? 'border-gold/40 shadow-[0_8px_40px_rgba(229,194,107,0.12)]' : ''}`}
    >
      <div className="mb-3 flex items-center gap-2">
        <span className="text-lg leading-none">{flagEmoji(country.country)}</span>
        <span className={`text-sm font-bold ${highlight ? 'text-gold' : 'text-fg'}`}>
          {country.countryName || 'Worldwide'}
        </span>
      </div>
      <div className="flex flex-wrap gap-2">
        {country.broadcasters.map((b, i) =>
          b.url ? (
            <a
              key={`${b.name}-${i}`}
              href={b.url}
              target="_blank"
              rel="noreferrer nofollow"
              className="inline-flex items-center gap-1.5 rounded-full border border-border bg-surface-2 px-3 py-1.5 text-xs font-semibold text-fg transition hover:border-gold/40 hover:text-gold"
            >
              {b.name}
              <span aria-hidden className="text-[10px] opacity-60">↗</span>
            </a>
          ) : (
            <span
              key={`${b.name}-${i}`}
              className="inline-flex items-center rounded-full border border-border bg-surface-1 px-3 py-1.5 text-xs font-medium text-fg-soft"
            >
              {b.name}
            </span>
          ),
        )}
      </div>
    </div>
  );
}
