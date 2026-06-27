# FootballMojo — World Cup 2026 SEO sprint (pass 1)

Status: **built + `next build` passes**. Pages render real backend data (live, ISR) with
graceful **noindex "coming soon"** states where data isn't available yet (anti-spam guardrail).
All Play CTAs carry UTM `?utm_source=web&utm_medium=organic&utm_campaign=worldcup2026&utm_content=<slug>`.

## Page → target keyword → title / meta (for human review before launch)

| Route | Primary keyword(s) | `<title>` (≤60) | Meta description (≤155) | Index |
|---|---|---|---|---|
| `/world-cup-2026` | world cup 2026, schedule, fixtures, live scores, bracket | World Cup 2026 Schedule, Fixtures & Live Scores | Full FIFA World Cup 2026 schedule, fixtures, live scores, group standings, knockout bracket and host cities — free, no betting. Get live goal alerts. | ✅ |
| `/world-cup-2026/fixtures` | world cup 2026 fixtures, match schedule | World Cup 2026 Fixtures — Full Match Schedule | Every FIFA World Cup 2026 fixture by date — kick-off times in your timezone, live scores and results. Free, no betting. | ✅ |
| `/world-cup-2026/fixtures/[date]` | [date] world cup fixtures | World Cup 2026 Fixtures — {date} | All FIFA World Cup 2026 matches on {date} — kick-off times in your timezone, live scores and results. | ✅ in-window · ⛔ noindex out-of-window |
| `/world-cup-2026/groups/[a–l]` | world cup 2026 group X table/standings | World Cup 2026 Group X — Table & Fixtures | FIFA World Cup 2026 Group X: live standings, fixtures and results. See who tops the group and who qualifies. | ✅ |
| `/world-cup-2026/match/[slug]` | [team] vs [team] world cup | {Home} vs {Away} — World Cup 2026 | Pre: kick-off, preview, H2H, live score. Post: result + recap + stats. | ✅ resolved · ⛔ noindex if slug unknown |
| `/leagues/premier-league` | premier league fixtures / live scores / table | Premier League Fixtures, Live Scores & Table | Premier League fixtures, live scores, results and standings — free, no betting. AI previews in the app. | ✅ |
| `/leagues/champions-league` | champions league / ucl | Champions League Fixtures, Live Scores & Table | — | ✅ |
| `/leagues/la-liga` | la liga | LaLiga Fixtures, Live Scores & Table | — | ✅ |
| `/leagues/serie-a` | serie a, classifica | Serie A Fixtures, Live Scores & Table | — | ✅ |
| `/leagues/bundesliga` | bundesliga, tabellen | Bundesliga Fixtures, Live Scores & Table | — | ✅ |
| `/leagues/isl` | ISL, indian super league | ISL Fixtures, Live Scores & Table | — | ✅ |
| `/leagues/i-league` | i-league | I-League Fixtures, Live Scores & Table | — | ✅ |
| `/best-football-score-apps` | best football score apps, no betting / halal | Best Football Score Apps (2026): Honest Comparison | Best football & soccer live-score apps in 2026 — and the best halal, no-betting option for World Cup 2026. | ✅ |
| `/blog` | world cup 2026 guides | FootballMojo Blog — World Cup 2026 Guides | — | ✅ |
| `/blog/how-to-watch-world-cup-2026` | how to watch world cup 2026 | How to Watch World Cup 2026: Schedule & Live Scores | — | ✅ |
| `/blog/world-cup-2026-groups-and-bracket-guide` | world cup 2026 groups & bracket | World Cup 2026 Groups & Bracket Guide | — | ✅ |
| `/blog/best-halal-no-gambling-football-apps` | halal / no gambling football apps | Best Halal, No-Gambling Football Apps (2026) | — | ✅ |

## SEO mechanics shipped
- Unique `<title>` + meta description per page (`pageMeta` in `lib/seo.ts`).
- Canonical + hreflang (`x-default`/`en`) per page; **OpenGraph + Twitter** per page (root `opengraph-image.tsx` supplies the image; per-route OG images = TODO below).
- JSON-LD: `BreadcrumbList` sitewide, `FAQPage` (hub + best-apps), `SportsEvent` (match pages), `MobileApplication` (hub), `Article` (blog posts), `Organization`/`WebSite` (root layout). **`aggregateRating` intentionally omitted — never fake ratings.**
- `sitemap.xml` regenerated to include every new route (incl. per-date, per-group, per-match from live data); `robots.txt` now disallows `/api/`.
- Timezone-aware kick-off times (`KickoffTime`, client-side; SSR shows UTC fallback → no CLS).
- ISR revalidate: hub/fixtures/leagues 600s, groups/match 300s, editorial/blog 1d.

## ⚠️ Known gaps / pass-2 TODO (call these out before launch)
1. **i18n (locale routes).** Pass 1 ships **English at root** with the i18n scaffold (`LOCALES`, hreflang helper) in place. The 12 non-English locale routes are **not built yet** — they need the human-reviewed translations (titles/H1/meta per the keyword lists). Doing them as thin machine translations would trip the anti-spam guardrail, so they're deliberately deferred. `hreflangFor` currently emits only `x-default`+`en`; expand it when locale routes land.
2. **Per-route OG images.** All pages currently fall back to the root `opengraph-image.tsx`. Add dynamic `@vercel/og` (`next/og` `ImageResponse`) per route (match scoreline cards, group cards) for better social CTR.
3. **MDX blog.** Posts are structured data in `lib/blog.ts` (zero new deps). Swap to `@next/mdx` if you want rich authoring.
4. **Match-page resolution** scans the tournament fixtures feed per request (ISR-cached). Fine now; add a backend `GET /scores/match-by-slug` (or include a slug/date in the fixtures payload) to make it O(1) at scale.
5. **Knockout bracket** shows a "coming soon" until Round-of-32 fixtures exist (28 Jun). It auto-populates from `stage`-tagged fixtures — verify the backend sets `stage` (ROUND_OF_32 etc.) on knockout rows.
6. **Data dependency:** every page reads the live backend (`API_URL`, default `https://api.footballmojo.in/api/v1`). If a build runs where the API is unreachable, pages render the graceful empty states (no crash) but won't be index-worthy — ensure the API is reachable at build/ISR time.

## Verify before/after launch
- `npm run build` (passes) → deploy → submit updated `sitemap.xml` in Google Search Console.
- Spot-check Rich Results for `SportsEvent` (a match URL) and `FAQPage` (the hub).
- Confirm `stage` is populated on knockout fixtures so the bracket + match pages light up.
