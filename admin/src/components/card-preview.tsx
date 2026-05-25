'use client';

import Image from 'next/image';

/**
 * Mini PCard preview — mirrors the Flutter PCard chrome (cosmic-free
 * rich-gradient design) so the admin can see exactly how a photo will
 * land on the mobile card before saving.
 *
 * Not pixel-identical to the Flutter widget on purpose: we mock the
 * shape, gradient, and photo treatment but skip the holographic sheen +
 * sparkle — those add noise that hurts the photo evaluation.
 */
export function CardPreview({
  rarity = 'EPIC',
  photoUrl,
  firstName,
  lastName,
  country,
  position,
  clubCrestUrl,
  editionLabel,
}: {
  rarity?: keyof typeof RARITY_THEMES;
  photoUrl?: string | null;
  firstName?: string | null;
  lastName?: string | null;
  country?: string | null;
  position?: string | null;
  clubCrestUrl?: string | null;
  editionLabel?: string | null;
}) {
  const theme = RARITY_THEMES[rarity];
  const isCutout = !!photoUrl && photoUrl.includes('thesportsdb.com');

  return (
    <div className="aspect-[0.66] w-full max-w-[240px] rounded-lg overflow-hidden relative shadow-card" style={{ background: theme.gradient }}>
      {/* Radial highlight */}
      <div className="absolute inset-0" style={{ background: `radial-gradient(ellipse 130% 80% at 50% -10%, ${theme.accent}55, transparent 60%)` }} />
      {/* Specular */}
      <div className="absolute inset-0 opacity-50" style={{ background: 'linear-gradient(135deg, rgba(255,255,255,0.10) 0%, transparent 35%, transparent 70%, rgba(255,255,255,0.06) 100%)' }} />
      {/* Inner frame */}
      <div className="absolute inset-1 rounded-md border border-white/5" />

      {/* Floor glow (cutout only) */}
      {isCutout && (
        <div
          className="absolute left-1/2 -translate-x-1/2"
          style={{
            bottom: '24%',
            width: '70%',
            height: '14%',
            background: `radial-gradient(ellipse at center, ${theme.accent}60 0%, ${theme.accent}20 50%, transparent 100%)`,
          }}
        />
      )}

      {/* Photo */}
      {photoUrl ? (
        <div className={isCutout ? 'absolute inset-0 left-0.5 right-0.5 top-3 bottom-[34%]' : 'absolute inset-0 left-2 right-2 top-12 bottom-[40%]'}>
          <Image
            src={photoUrl}
            alt=""
            fill
            sizes="240px"
            className="object-contain object-bottom"
            unoptimized
          />
        </div>
      ) : (
        <div className="absolute inset-0 flex items-center justify-center text-6xl font-black text-white/10">
          {(lastName ?? '·').slice(0, 2).toUpperCase()}
        </div>
      )}

      {/* Top-right crest */}
      {clubCrestUrl && (
        <div className="absolute top-2 right-2 w-6 h-6 rounded-full bg-black/20 border border-white/10 p-0.5 backdrop-blur-sm">
          <Image src={clubCrestUrl} alt="" fill sizes="24px" className="object-contain p-0.5" unoptimized />
        </div>
      )}

      {/* Bottom block */}
      <div className="absolute left-0 right-0 bottom-0 px-3 py-2" style={{ background: 'linear-gradient(to bottom, transparent 0%, rgba(5,6,8,0.8) 35%, #030406 100%)' }}>
        <div className="flex items-center gap-2 mb-1.5">
          {country && <Meta label="Country" value={country.slice(0, 3).toUpperCase()} accent={theme.accent} />}
          {position && (
            <>
              {country && <div className="w-px h-2 bg-white/20" />}
              <Meta label="Pos" value={position.toUpperCase()} accent={theme.accent} />
            </>
          )}
        </div>
        {firstName && (
          <div className="text-[10px] font-bold tracking-tight text-white leading-none uppercase truncate">
            {firstName}
          </div>
        )}
        <div className="text-base font-extrabold tracking-tight text-white leading-tight uppercase truncate">
          {lastName ?? '—'}
        </div>
        {editionLabel && (
          <div className="text-[7px] font-bold tracking-widest text-white/40 mt-1 font-mono uppercase truncate">
            {editionLabel}
          </div>
        )}
      </div>
    </div>
  );
}

function Meta({ label, value, accent }: { label: string; value: string; accent: string }) {
  return (
    <div className="flex items-baseline gap-1">
      <span className="text-[6px] font-bold tracking-widest text-white/40 font-mono uppercase leading-none">{label}</span>
      <span className="text-[9px] font-extrabold leading-none" style={{ color: accent }}>{value}</span>
    </div>
  );
}

const RARITY_THEMES = {
  COMMON:    { gradient: 'linear-gradient(180deg, #3A4150 0%, #222730 55%, #11141A 100%)', accent: '#8C97AB' },
  UNCOMMON:  { gradient: 'linear-gradient(180deg, #2EA070 0%, #155A3D 55%, #06251A 100%)', accent: '#7FE3B5' },
  RARE:      { gradient: 'linear-gradient(180deg, #3A98E5 0%, #1E4E8E 55%, #071735 100%)', accent: '#7EC8FF' },
  EPIC:      { gradient: 'linear-gradient(180deg, #9B4FE4 0%, #4E1E94 55%, #160534 100%)', accent: '#C489FF' },
  LEGENDARY: { gradient: 'linear-gradient(180deg, #E8C778 0%, #8E6422 55%, #2D1E08 100%)', accent: '#FFD884' },
  ICONIC:    { gradient: 'linear-gradient(135deg, #E15FB8 0%, #7044D6 45%, #0B0418 100%)', accent: '#FFA3DC' },
} as const;
