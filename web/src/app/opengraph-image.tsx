import { ImageResponse } from 'next/og';
import { SITE } from '@/lib/site';

export const runtime = 'edge';
export const alt = `${SITE.name} — World Cup 2026 football app`;
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

// Branded social-share card, generated at the edge — no static asset needed.
export default function OpengraphImage() {
  return new ImageResponse(
    (
      <div
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'space-between',
          padding: '80px',
          background:
            'radial-gradient(1000px 700px at 15% -10%, rgba(229,194,107,0.22), transparent 60%), radial-gradient(900px 600px at 100% 110%, rgba(62,173,106,0.18), transparent 60%), #0B0A09',
          color: '#F7F2E6',
          fontFamily: 'sans-serif',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          <div
            style={{
              fontSize: 30,
              fontWeight: 800,
              letterSpacing: 2,
              color: '#E5C26B',
              textTransform: 'uppercase',
            }}
          >
            FIFA World Cup 2026
          </div>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <div style={{ display: 'flex', fontSize: 84, fontWeight: 800, lineHeight: 1.05 }}>
            <span>Football</span>
            <span style={{ color: '#E5C26B' }}>Mojo</span>
          </div>
          <div style={{ marginTop: 24, fontSize: 36, color: '#CBC4B2', maxWidth: 900 }}>
            Live scores · brackets · fantasy XI · predictions · collectible cards
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, fontSize: 28, color: '#8C8779' }}>
          <span>Free on Google Play</span>
          <span>·</span>
          <span>{SITE.domain}</span>
        </div>
      </div>
    ),
    { ...size },
  );
}
