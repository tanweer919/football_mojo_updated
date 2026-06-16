'use client';

import { useState, useTransition } from 'react';
import { useRouter } from 'next/navigation';
import { Button, Field, Input, Panel, SectionHead } from '@/components/ui';
import { api } from '@/lib/api-client';

/**
 * Set or clear a fixture's FIFA-official YouTube highlight link.
 * `PATCH /admin/fixtures/:id/highlight` with `{ highlightUrl }` (empty clears).
 *
 * The app plays the video in-app, so any standard YouTube URL works —
 * watch?v=, youtu.be/, shorts/, or embed/. We parse the id for a live
 * thumbnail preview so the admin can confirm they pasted the right clip.
 */
function youtubeId(raw: string): string | null {
  const url = raw.trim();
  if (!url) return null;
  // Bare 11-char id.
  if (/^[a-zA-Z0-9_-]{11}$/.test(url)) return url;
  const patterns = [
    /[?&]v=([a-zA-Z0-9_-]{11})/,
    /youtu\.be\/([a-zA-Z0-9_-]{11})/,
    /youtube\.com\/(?:embed|shorts|v)\/([a-zA-Z0-9_-]{11})/,
  ];
  for (const re of patterns) {
    const m = url.match(re);
    if (m) return m[1];
  }
  return null;
}

export function HighlightEditor({
  matchId,
  initial,
  initialSource,
}: {
  matchId: string;
  initial: string | null;
  initialSource: 'AUTO' | 'ADMIN' | null;
}) {
  const [url, setUrl] = useState(initial ?? '');
  const [pending, startTransition] = useTransition();
  const [error, setError] = useState<string | null>(null);
  const [savedAt, setSavedAt] = useState<Date | null>(null);
  const router = useRouter();

  const trimmed = url.trim();
  const id = youtubeId(trimmed);
  const dirty = trimmed !== (initial ?? '');
  // Block obviously-wrong links: non-empty but no parseable id.
  const invalid = trimmed.length > 0 && !id;

  function save(clear = false) {
    setError(null);
    const next = clear ? '' : trimmed;
    if (!clear && invalid) {
      setError("That doesn't look like a YouTube link.");
      return;
    }
    startTransition(async () => {
      try {
        await api(`/fixtures/${matchId}/highlight`, {
          method: 'PATCH',
          body: JSON.stringify({ highlightUrl: next }),
        });
        if (clear) setUrl('');
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
        eyebrow="Highlights"
        title="Highlight video"
        action={
          !initial ? (
            <span className="text-xs font-mono text-fg-muted2">None</span>
          ) : initialSource === 'ADMIN' ? (
            <span className="text-xs font-mono text-gold">Set by admin</span>
          ) : (
            <span className="text-xs font-mono text-pitch">Auto-matched</span>
          )
        }
      />
      <p className="text-xs text-fg-muted2 mb-3 leading-relaxed">
        Highlights are matched <span className="text-fg-soft">automatically</span> from the FIFA
        playlist a while after full time. Set a link here to override or fill one in early —
        an admin link is <span className="text-fg-soft">never replaced</span> by the auto-matcher.
        {' '}If a clip won&apos;t play in-app (the owner disabled embedding, e.g. some FIFA uploads),
        paste an <span className="text-fg-soft">embeddable</span> YouTube link from a rights-holder
        that allows it — embeddable links play inline; blocked ones open in the YouTube app.
      </p>
      <div className="grid grid-cols-1 sm:grid-cols-[1fr_auto] gap-4 items-end">
        <Field label="YouTube URL" hint={id ? `Video id: ${id}` : 'watch?v=… · youtu.be/… · embed/…'}>
          <Input
            value={url}
            onChange={(e) => setUrl(e.target.value)}
            placeholder="https://www.youtube.com/watch?v=…"
            className={invalid ? 'border-live' : undefined}
          />
        </Field>
        <div className="flex gap-2">
          {initial && (
            <Button variant="ghost" onClick={() => save(true)} disabled={pending}>
              Clear
            </Button>
          )}
          <Button variant="gold" onClick={() => save(false)} disabled={!dirty || invalid || pending}>
            {pending ? 'Saving…' : 'Save link'}
          </Button>
        </div>
      </div>

      {id && (
        <a
          href={`https://www.youtube.com/watch?v=${id}`}
          target="_blank"
          rel="noreferrer"
          className="mt-4 inline-block overflow-hidden rounded-lg border border-border hover:border-gold transition-colors"
        >
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img src={`https://i.ytimg.com/vi/${id}/mqdefault.jpg`} alt="Highlight thumbnail" width={240} height={135} className="block" />
        </a>
      )}

      {(error || savedAt) && (
        <div className="mt-3">
          {error && <span className="text-xs text-live">{error}</span>}
          {!error && savedAt && (
            <span className="text-xs font-mono text-pitch">Saved {savedAt.toLocaleTimeString()}</span>
          )}
        </div>
      )}
    </Panel>
  );
}
