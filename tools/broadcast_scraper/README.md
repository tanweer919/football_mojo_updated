# Broadcast scraper (where-to-watch)

Scrapes per-country TV/stream broadcaster listings from **livesoccertv.com** and
emits JSON for the backend's `GET /v1/insights/broadcasts/{fixtureId}` endpoint
(the Flutter client is already wired to it — see `broadcast_dto.dart` /
`_WhereToWatchBlock`). Built because the only reliable paid API (Sportmonks TV
Stations) is ~$69/mo.

## Why it works when `curl` doesn't

livesoccertv is behind Cloudflare and returns **403 to plain HTTP clients**. This
scraper fetches through the **Jina Reader proxy** (`https://r.jina.ai/<url>`,
`X-Return-Format: html`), which renders the page and returns clean HTML. Free to
use; set `JINA_API_KEY` (free key at jina.ai) for higher rate limits.

## Setup

```bash
pip install -r requirements.txt
export JINA_API_KEY=...        # optional but recommended
```

## Run

```bash
python scraper.py --days 7                            # next 7 days → broadcasts_raw.json
python scraper.py --date 2026-06-13                   # one day
python scraper.py --days 2 --limit 3                  # quick smoke test
python scraper.py --days 7 --no-watch-links           # skip watch-URL resolution (faster)

# Map onto your fixtures + push to the backend — fixtures fetched automatically:
python scraper.py --days 7 \
  --fixtures-api https://api.footballmojo.in/api/v1 \
  --ingest-url   https://api.footballmojo.in/api/v1/admin/broadcasts/ingest
```

HTML is cached under `.cache/` so re-runs are instant; pass `--no-cache` to refetch.

### Fixtures: no file needed

Pass **`--fixtures-api <backend-base-url>`** and the scraper pulls the fixture list
(id/date/home/away) straight from the public `/scores/fixtures/range` endpoint for
the same date window — no hand-made `fixtures.json`. (A `--fixtures file.json` still
works if you prefer; a missing file is now a warning, not a crash.)

### Rate limits (HTTP 429) — get a Jina key

The **free Jina tier rate-limits hard**. Without a key you'll see `HTTP 429` and slow
retries, and `--concurrency` is auto-capped to 3. Fix it in 30 seconds:

```bash
export JINA_API_KEY=...   # free at jina.ai → then --concurrency 12 is fine
```

On 429 the scraper honors `Retry-After`, backs off exponentially, and makes **all
threads** pause together. Failed pages/days recover on retry, and re-running reuses
`.cache/` + `channels.json`, so nothing is re-fetched needlessly.

### Watch links & the channel directory (speed)

For each broadcaster the scraper resolves the real **"Channel Website"** watch URL
from its livesoccertv channel page (e.g. ZEE5 → `zee5.com`, ITV → `itv.com`), and
leaves `url: null` for TV-only channels that have none.

This is the only slow part, so it's built to be done **once and reused everywhere**:

- Resolution runs **in parallel** (`--concurrency`, default 8) in a single pass
  over *all* unique channels across every fetched fixture — not per-match.
- The slug → website map is persisted to **`channels.json` at the scraper root and
  committed to git** (not in `.cache/`). It's a global, stable directory: broadcaster
  sites don't change per match, so every fixture, every run, and a fresh machine all
  reuse it. After the first warm-up, runs resolve ~0 new channels and finish fast.

Pass `--no-watch-links` to skip resolution entirely. Match pages are also fetched
`--concurrency`-way in parallel.

#### Fixing / adding a channel's link

Some channels have no "Channel Website" on livesoccertv (e.g. US: FOX Network,
fuboTV) → `url: null`. To set one **globally for every fixture**, add the slug →
URL to **`channel-overrides.json`** (committed; always wins; never auto-written):

```json
{ "fox-network": "https://www.foxsports.com/live", "fubo-tv": "https://www.fubo.tv/" }
```

The slug is the `/channels/<slug>/` path on livesoccertv — and it's **channel-
specific, not network-wide**: e.g. "FOX Network" is `fox-network` but "Fox Sports 1"
is `fox-sports-1-usa` and "FOX One" is `fox-one`, all different. Overriding one
won't touch the others.

Don't guess — run **`--report-missing`** to list every channel that still has no
link, with its exact slug, and a ready-to-fill `missing-links.json`:

```bash
python scraper.py --days 7 --report-missing
# → prints "Fox Sports 1   slug=fox-sports-1-usa  (×12)" etc.
#   + writes missing-links.json = { "fox-sports-1-usa": "", … }
```

Fill in the URLs, merge those entries into `channel-overrides.json`, then re-run
the scraper + re-ingest — overrides apply everywhere that channel appears and
overridden slugs are skipped during resolution.

For a **one-off, single-fixture** link, just edit it in the **admin panel**:
Fixtures → the match → Watch links → Edit.

> **Coverage is ~identical across World Cup fixtures** (India is always ZEE5, USA
> always FOX, …). The committed `channels.json` captures that shared directory, and
> the per-fixture scrape is then a single fast page fetch each.

### Push straight to the backend (cron)

Instead of writing a file, POST the matched results to the backend ingest endpoint
(`POST /v1/admin/broadcasts/ingest`, guarded by a static `x-ingest-key`):

```bash
export SCRAPER_INGEST_KEY=...   # must equal the backend's SCRAPER_INGEST_KEY env
python scraper.py --days 7 --fixtures fixtures.json \
  --ingest-url https://api.footballmojo.in/api/v1/admin/broadcasts/ingest
```

Ingest **replaces only SCRAPER-sourced links** for each fixture — links curated by
admins in the panel are never touched.

## Output

`broadcasts_raw.json` — one object per match:

```json
{
  "date": "2026-06-13", "home": "Brazil", "away": "Morocco",
  "timeText": "6:00pm", "sourceUrl": "https://www.livesoccertv.com/match/…",
  "broadcasts": [
    { "country": "IN", "countryName": "India",
      "broadcasters": [ { "name": "ZEE5", "url": "https://…", "logo": null } ] }
  ]
}
```

That `broadcasts` array is exactly the shape the backend endpoint should return.

### Mapping to fixtures

livesoccertv has no api-football IDs, so matches are keyed by date + team names.
Pass `--fixtures fixtures.json` (export from your backend):

```json
[ { "id": "1390531", "date": "2026-06-13", "home": "USA", "away": "Paraguay" } ]
```

→ `broadcasts_by_fixture.json`: `{ "1390531": [ <broadcasts…> ] }`, ready to store
and serve. Team matching is fuzzy (accent/suffix-insensitive, ±1 day, both
orientations); eyeball the match rate the script prints and add aliases if needed.

## Suggested wiring

Run nightly (cron) for the next N days → upload `broadcasts_by_fixture.json` to the
backend / a table the endpoint reads. Keep TTL short; rights listings change.

## Caveats — read these

- **Terms of Service.** `robots.txt` permits `/schedules/` and `/match/`, but
  scraping + redistributing their broadcaster compilation may breach their ToS /
  their copyright. This is fine for personal or modest scale; get advice before
  shipping it commercially at volume. Crawl politely (the script rate-limits and
  caches) — don't hammer them.
- **Fragility.** Selectors live in `SELECTORS` at the top of `scraper.py`,
  verified June 2026. When livesoccertv changes markup, fix them there.
- **Coverage.** ~200 countries per match, but only fixtures livesoccertv lists
  (roughly ±14 days). No source is perfectly accurate; rights shift.
- **Watch links / logos.** `url` is the broadcaster's official site scraped from
  the channel page ("Channel Website"), or null for TV-only channels. It's the
  broadcaster homepage, not a deep link to this specific match. `logo` is always
  null (livesoccertv shows none inline) — map your own if you want them in the UI.
