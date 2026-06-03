# FootballMojo — marketing site

Next.js 14 (App Router) landing page + privacy policy for **FootballMojo**.
Deploys to **pitch.footballmojo.in**.

## What's here

- `/` — landing page (hero, features, screenshot gallery, World Cup 2026 + cards bands, FAQ, CTA).
- `/privacy` — full privacy policy (Google AdMob, analytics, GDPR, CCPA, children, etc.).
- SEO: per-page metadata, Open Graph + Twitter cards, JSON-LD (`MobileApplication`,
  `Organization`, `WebSite`, `FAQPage`), `sitemap.xml`, `robots.txt`, web manifest, and a
  dynamically-generated OG image (`opengraph-image.tsx` — no static asset needed).

## You need to add: app screenshots

Drop **5 portrait phone screenshots** in [`public/screenshots/`](public/screenshots/README.md):

`home.png`, `bracket.png`, `fantasy.png`, `cards.png`, `news.png`

Portrait, ~9:19.5 (e.g. 1080×2340), no device chrome — the site draws the phone frame.
Until they exist the frames render empty (the build still succeeds).

The logo (`public/logo.png`) is already in place (the app icon). Swap it if you have a
dedicated web logo.

## Develop

```bash
cd web
npm install
npm run dev        # http://localhost:3002
npm run typecheck  # tsc --noEmit
npm run build      # production build
```

> Fonts (Inter, Sora) are fetched at build time via `next/font/google`, so the build needs
> network access — fine on Vercel/CI.

## Deploy (Vercel)

1. New Vercel project → import this repo → set **Root Directory** to `web`.
2. Framework preset: **Next.js** (defaults are correct; no env vars required).
3. Add the custom domain **pitch.footballmojo.in** and point its DNS (CNAME → Vercel) per
   Vercel's instructions.

`SITE.url` in `src/lib/site.ts` is already set to `https://pitch.footballmojo.in` (used for
canonical URLs, sitemap, OG). Update `src/lib/site.ts` if any contact emails or the Play
Store ID change.
