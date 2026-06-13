#!/usr/bin/env python3
"""
LiveSoccerTV "where to watch" scraper for FootballMojo.

Scrapes per-country TV/stream broadcaster listings for football fixtures from
livesoccertv.com and emits JSON shaped for the backend's broadcast endpoint
(`GET /v1/insights/broadcasts/{fixtureId}` — see broadcast_dto.dart).

WHY A PROXY: livesoccertv sits behind Cloudflare and 403s plain HTTP clients
(requests/curl). We fetch through the Jina Reader proxy (https://r.jina.ai),
which renders the page server-side and returns clean HTML, sidestepping the
bot wall. Set JINA_API_KEY for higher rate limits (free key at jina.ai).

READ BEFORE USING:
  • This scrapes a third-party site. Check livesoccertv's Terms of Service —
    robots.txt allows /schedules/ and /match/ (only /video/ + a few PHP
    endpoints are disallowed), but ToS is a separate matter. The broadcaster
    listings may be their copyrighted compilation. Use for personal / modest
    scale, cache aggressively, and crawl politely (this script rate-limits).
  • Selectors WILL break when livesoccertv changes markup. They're centralised
    in SELECTORS below — fix there. Verified against the live site June 2026.
  • Output still needs fixture matching: livesoccertv has no api-football IDs,
    so we match by date + team name (see --fixtures).

Usage:
  python scraper.py --days 7                          # scrape next 7 days → broadcasts_raw.json
  python scraper.py --date 2026-06-13                 # a single day
  python scraper.py --days 7 --fixtures fixtures.json # also map to api-football fixture IDs
  python scraper.py --days 3 --no-cache               # bypass the on-disk HTML cache
  python scraper.py --days 7 --concurrency 12         # more parallel fetches

SPEED: match pages and channel-website resolution run in parallel
(`--concurrency`). The slug→website map persists to a committed `channels.json`
(global + stable), so each channel is resolved once ever and reused by every
fixture/run — warm runs finish fast.

fixtures.json (export from your backend / api-football) is a list of:
  [ { "id": "1390531", "date": "2026-06-13", "home": "USA", "away": "Paraguay" }, ... ]
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
import threading
import time
import unicodedata
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import requests
from bs4 import BeautifulSoup

try:
    import pycountry
except ImportError:  # optional but strongly recommended
    pycountry = None

LSTV = "https://www.livesoccertv.com"
READER = "https://r.jina.ai/"

# ── Selectors (verified against livesoccertv June 2026 — fix here if markup moves) ──
SELECTORS = {
    "match_row": "tr.matchrow",                 # schedule page: one row per fixture
    "match_link": 'a[href*="/match/"]',         #   → href + "Home vs Away" text
    "time_cell": "td.timecol",                  #   → local kickoff time text
    "channel_table": "table.data.ichannels",    # match page: country → channels table
    "channel_link": 'a[href*="/channels/"]',    #   → broadcaster name + lstv channel page
}

# livesoccertv country labels that pycountry can't resolve on its own.
COUNTRY_OVERRIDES = {
    "usa": "US", "great britain": "GB", "england": "GB", "scotland": "GB",
    "wales": "GB", "northern ireland": "GB", "ireland republic": "IE",
    "korea republic": "KR", "korea dpr": "KP", "congo dr": "CD",
    "congo": "CG", "côte d'ivoire": "CI", "cote d'ivoire": "CI",
    "cape verde islands": "CV", "chinese taipei": "TW", "czech republic": "CZ",
    "russia": "RU", "moldova": "MD", "macedonia": "MK", "swaziland": "SZ",
    "bosnia and herzegovina": "BA", "st. vincent / grenadines": "VC",
    "saint martin": "MF", "são tomé and príncipe": "ST", "reunion": "RE",
    "macau": "MO", "hong kong": "HK", "iran": "IR", "syria": "SY",
    "turkey": "TR", "turkiye": "TR",  # recent pycountry only knows "Türkiye"
    "tanzania": "TZ", "venezuela": "VE", "bolivia": "BO", "vietnam": "VN",
    "laos": "LA", "brunei darussalam": "BN", "palestine": "PS",
    "saint helena": "SH", "turks and caicos islands": "TC",
}
SKIP_COUNTRIES = {"international"}  # pseudo-rows with no ISO code


# ───────────────────────────────── rate limiting ──────────────────────────────────
# The Jina free tier rate-limits hard (HTTP 429). When any thread is told to back
# off, ALL threads honor a shared cooldown so we don't thunder-herd straight into
# more 429s. A JINA_API_KEY raises the limit dramatically — strongly recommended.
_rate_lock = threading.Lock()
_cooldown_until = 0.0  # monotonic time before which no request should start


def _wait_for_cooldown() -> None:
    while True:
        with _rate_lock:
            remaining = _cooldown_until - time.monotonic()
        if remaining <= 0:
            return
        time.sleep(min(remaining, 3))


def _set_cooldown(seconds: float) -> None:
    global _cooldown_until
    with _rate_lock:
        _cooldown_until = max(_cooldown_until, time.monotonic() + seconds)


# ───────────────────────────────────── fetch ──────────────────────────────────────
def fetch(url: str, cache: Path | None, api_key: str | None, delay: float, attempts: int = 6) -> str:
    """GET a livesoccertv URL's rendered HTML via the Jina reader proxy, cached.
    Retries with exponential backoff, honoring Retry-After and a shared cooldown."""
    if cache:
        key = re.sub(r"[^a-z0-9]+", "_", url.lower()).strip("_") + ".html"
        cached = cache / key
        if cached.exists():
            return cached.read_text(encoding="utf-8", errors="ignore")

    headers = {"X-Return-Format": "html"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    last_err = None
    for attempt in range(attempts):
        _wait_for_cooldown()
        try:
            r = requests.get(READER + url, headers=headers, timeout=60)
            if r.status_code == 200 and r.text:
                time.sleep(delay)  # be polite
                if cache:
                    cache.mkdir(parents=True, exist_ok=True)
                    cached.write_text(r.text, encoding="utf-8")
                return r.text
            if r.status_code == 429:
                ra = r.headers.get("Retry-After", "")
                backoff = float(ra) if ra.isdigit() else min(90, 5 * (2 ** attempt))
                # Spread the resume time a little so threads don't all fire at once.
                _set_cooldown(backoff + (attempt % 4))
                last_err = "HTTP 429 (rate limited)"
                continue  # cooldown above handles the wait
            last_err = f"HTTP {r.status_code}"
        except requests.RequestException as e:
            last_err = str(e)
        time.sleep(min(30, 2 * (attempt + 1)))  # backoff for non-429 errors
    raise RuntimeError(f"fetch failed for {url}: {last_err}")


# ───────────────────────────────────── parse ──────────────────────────────────────
def parse_schedule(html: str) -> list[dict]:
    """Schedule page → [{slug_url, home, away, time_text}] for matches that have TV."""
    soup = BeautifulSoup(html, "html.parser")
    out = []
    for tr in soup.select(SELECTORS["match_row"]):
        link = tr.select_one(SELECTORS["match_link"])
        if not link:
            continue
        href = link.get("href", "").split("#")[0]
        title = link.get_text(" ", strip=True)
        if " vs " not in title:
            continue
        home, away = (s.strip() for s in title.split(" vs ", 1))
        tcell = tr.select_one(SELECTORS["time_cell"])
        out.append({
            "url": LSTV + href if href.startswith("/") else href,
            "home": home,
            "away": away,
            "time_text": tcell.get_text(" ", strip=True) if tcell else None,
            "has_tv": tr.get("data-has-tv") == "1",
        })
    return out


def parse_match(html: str) -> list[dict]:
    """Match page → [{country, countryCode, broadcasters:[{name, url}]}] per country."""
    soup = BeautifulSoup(html, "html.parser")
    table = soup.select_one(SELECTORS["channel_table"])
    if not table:
        return []
    out, seen = [], set()
    for tr in table.find_all("tr"):
        tds = tr.find_all("td", recursive=False) or tr.find_all("td")
        if len(tds) < 2:
            continue
        country_name = tds[0].get_text(" ", strip=True)
        if not country_name or country_name.lower() in seen:
            continue
        links = tds[1].select(SELECTORS["channel_link"])
        if not links:
            continue
        seen.add(country_name.lower())
        broadcasters = []
        seen_ch: set[str] = set()  # dedupe within a country (livesoccertv repeats some)
        for a in links:
            name = a.get_text(strip=True)
            if not name or "…" in name:
                continue
            href = a.get("href", "")
            m = re.search(r"/channels/([^/]+)/?", href)
            slug = m.group(1) if m else None
            dedupe_key = slug or name.lower()
            if dedupe_key in seen_ch:
                continue
            seen_ch.add(dedupe_key)
            broadcasters.append({
                "name": name,
                # Real watch URL is filled in later from the channel page's
                # "Channel Website" button (see ChannelResolver); null if none.
                "url": None,
                "logo": None,
                "_slug": slug,
            })
        if broadcasters:
            out.append({
                "country": country_to_iso2(country_name) or "",
                "countryName": country_name,
                "broadcasters": broadcasters,
            })
    return out


# ─────────────────────────── channel → watch-link directory ───────────────────────
# Persisted next to the script (NOT in .cache) and committed, so the slug→website
# map is a shared, reusable asset — every fixture and every run reuses it, and a
# cold machine starts warm. This is the key to speed: broadcaster sites are global
# and stable, so each channel is resolved at most once, ever.
DIRECTORY_PATH = Path(__file__).resolve().parent / "channels.json"
# Manual, committed overrides that ALWAYS win — for channels livesoccertv has
# no "Channel Website" for (e.g. US: fox-network, fubo-tv). Hand-edit this file:
#   { "fox-network": "https://www.fox.com/live/", "fubo-tv": "https://www.fubo.tv/" }
# It's never auto-written, so your fixes are durable. Re-run + re-ingest to apply.
OVERRIDES_PATH = Path(__file__).resolve().parent / "channel-overrides.json"


def _load_overrides() -> dict[str, str]:
    if OVERRIDES_PATH.exists():
        try:
            return {k: v for k, v in json.loads(OVERRIDES_PATH.read_text(encoding="utf-8")).items() if v}
        except (ValueError, OSError):
            return {}
    return {}


class ChannelResolver:
    """Resolves livesoccertv channel slugs to the broadcaster's real "Channel
    Website" watch URL (the `a.watch-button` on /channels/{slug}/), in parallel.
    Manual `channel-overrides.json` entries take precedence over scraped ones.
    """

    def __init__(self, cache: Path | None, api_key: str | None, delay: float, concurrency: int):
        self.cache = cache
        self.api_key = api_key
        self.delay = delay
        self.concurrency = max(1, concurrency)
        self.map: dict[str, str | None] = {}
        self.overrides = _load_overrides()
        self._lock = threading.Lock()
        if DIRECTORY_PATH.exists():
            try:
                self.map = json.loads(DIRECTORY_PATH.read_text(encoding="utf-8"))
            except (ValueError, OSError):
                self.map = {}

    def website(self, slug: str | None) -> str | None:
        if not slug:
            return None
        return self.overrides.get(slug) or self.map.get(slug)

    def _resolve_one(self, slug: str) -> tuple[str, str | None]:
        site = None
        try:
            soup = BeautifulSoup(
                fetch(f"{LSTV}/channels/{slug}/", self.cache, self.api_key, self.delay),
                "html.parser",
            )
            for a in soup.select("a.watch-button[href], a.watch-btn[href]"):
                href = a.get("href", "")
                if href.startswith("http") and "livesoccertv.com" not in href and "r.jina.ai" not in href:
                    site = href
                    break
        except RuntimeError:
            site = None
        return slug, site

    def resolve_all(self, slugs: set[str | None]) -> None:
        """Resolve every not-yet-known slug concurrently, then persist once."""
        todo = sorted(s for s in slugs if s and s not in self.map and s not in self.overrides)
        if not todo:
            return
        print(f"resolving {len(todo)} new channel websites ({self.concurrency}-way parallel)…", file=sys.stderr)
        done = 0
        with ThreadPoolExecutor(max_workers=self.concurrency) as pool:
            futures = {pool.submit(self._resolve_one, s): s for s in todo}
            for fut in as_completed(futures):
                slug, site = fut.result()
                with self._lock:
                    self.map[slug] = site
                done += 1
                if done % 25 == 0 or done == len(todo):
                    print(f"  …{done}/{len(todo)}", file=sys.stderr)
        self.flush()

    def flush(self) -> None:
        DIRECTORY_PATH.write_text(json.dumps(self.map, ensure_ascii=False, indent=0, sort_keys=True), encoding="utf-8")


# ─────────────────────────────── normalisation helpers ────────────────────────────
def _strip_accents(s: str) -> str:
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


def country_to_iso2(name: str) -> str | None:
    key = _strip_accents(name).strip().lower()
    if key in SKIP_COUNTRIES:
        return None
    if key in COUNTRY_OVERRIDES:
        return COUNTRY_OVERRIDES[key]
    if pycountry:
        try:
            return pycountry.countries.lookup(name).alpha_2
        except LookupError:
            try:
                hits = pycountry.countries.search_fuzzy(name)
                if hits:
                    return hits[0].alpha_2
            except LookupError:
                pass
    return None


def normalize_team(name: str) -> str:
    """Loose key for matching livesoccertv team names to api-football names."""
    s = _strip_accents(name).lower()
    s = re.sub(r"\b(fc|cf|sc|afc|club|cd|ac|ss|us|if|fk|sk)\b", " ", s)
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return " ".join(s.split())


# ──────────────────────────────── fixture matching ────────────────────────────────
def match_fixtures(scraped: list[dict], fixtures: list[dict]) -> dict:
    """Map scraped matches onto api-football fixture IDs by date (+/-1d) + teams."""
    by_id = {}
    index = []  # (date, home_key, away_key, entry)
    for m in scraped:
        index.append((m["date"], normalize_team(m["home"]), normalize_team(m["away"]), m))
    for fx in fixtures:
        fdate = fx.get("date", "")
        fh, fa = normalize_team(fx.get("home", "")), normalize_team(fx.get("away", ""))
        best = None
        for sdate, sh, sa, entry in index:
            if not _date_close(fdate, sdate):
                continue
            # accept either orientation (slug order can differ from display)
            if {sh, sa} & {fh} and {sh, sa} & {fa} and _teams_match(fh, fa, sh, sa):
                best = entry
                break
        if best:
            by_id[str(fx["id"])] = best["broadcasts"]
    return by_id


def _teams_match(fh, fa, sh, sa) -> bool:
    return (_overlap(fh, sh) and _overlap(fa, sa)) or (_overlap(fh, sa) and _overlap(fa, sh))


def _overlap(a: str, b: str) -> bool:
    if not a or not b:
        return False
    if a == b or a in b or b in a:
        return True
    aw, bw = set(a.split()), set(b.split())
    return len(aw & bw) >= 1 and (len(aw & bw) / max(1, min(len(aw), len(bw)))) >= 0.5


def _date_close(d1: str, d2: str) -> bool:
    try:
        a = dt.date.fromisoformat(d1)
        b = dt.date.fromisoformat(d2)
        return abs((a - b).days) <= 1
    except ValueError:
        return d1 == d2


def fixtures_from_api(base_url: str, from_day: str, to_day: str) -> list[dict]:
    """Build the fixture list straight from the backend's public scores range
    endpoint, so no hand-made fixtures.json is needed. Returns id/date/home/away."""
    base = base_url.rstrip("/")
    url = f"{base}/scores/fixtures/range?from={from_day}&to={to_day}"
    rows = requests.get(url, timeout=30).json()
    out = []
    for r in rows:
        ko = r.get("kickoffAt") or ""
        out.append({
            "id": str(r.get("id")),
            "date": ko[:10],
            "home": (r.get("homeTeam") or {}).get("name", ""),
            "away": (r.get("awayTeam") or {}).get("name", ""),
        })
    return out


def load_fixtures(args, dates: list[str]) -> list[dict] | None:
    """Fixtures from --fixtures-api (preferred) or a --fixtures file. None if neither."""
    if args.fixtures_api:
        try:
            fx = fixtures_from_api(args.fixtures_api, dates[0], dates[-1])
            print(f"fetched {len(fx)} fixtures from {args.fixtures_api}", file=sys.stderr)
            return fx
        except (requests.RequestException, ValueError) as e:
            print(f"! could not fetch fixtures from API: {e}", file=sys.stderr)
            return None
    if args.fixtures:
        p = Path(args.fixtures)
        if not p.exists():
            print(f"! --fixtures file not found: {p} — skipping fixture mapping. "
                  f"(Tip: use --fixtures-api <backend-url> to fetch them automatically.)", file=sys.stderr)
            return None
        return json.loads(p.read_text(encoding="utf-8"))
    return None


# ─────────────────────────────────────── main ─────────────────────────────────────
def main() -> int:
    ap = argparse.ArgumentParser(description="Scrape livesoccertv where-to-watch data.")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--date", help="single day YYYY-MM-DD (default: today)")
    g.add_argument("--days", type=int, help="scrape today .. today+N days")
    ap.add_argument("--fixtures", help="fixtures.json (id/date/home/away) to map onto fixture IDs")
    ap.add_argument("--fixtures-api",
                    help="backend base URL to auto-fetch fixtures from instead of a file, "
                         "e.g. https://api.footballmojo.in/api/v1")
    ap.add_argument("--out", default="broadcasts_raw.json")
    ap.add_argument("--mapped-out", default="broadcasts_by_fixture.json")
    ap.add_argument("--no-cache", action="store_true", help="ignore on-disk HTML cache")
    ap.add_argument("--delay", type=float, default=1.0, help="seconds between requests (per thread)")
    ap.add_argument("--limit", type=int, default=0, help="cap matches per day (debug)")
    ap.add_argument("--no-watch-links", action="store_true",
                    help="skip resolving each channel's real watch URL (faster, fewer fetches)")
    ap.add_argument("--concurrency", type=int, default=6,
                    help="parallel fetches (keep low on the free Jina tier; raise with a key)")
    ap.add_argument("--ingest-url", help="POST broadcasts_by_fixture to this backend ingest endpoint")
    ap.add_argument("--ingest-key", default=os.environ.get("SCRAPER_INGEST_KEY"),
                    help="x-ingest-key header for --ingest-url (or SCRAPER_INGEST_KEY env)")
    args = ap.parse_args()

    today = dt.date.today()  # the scraper runs locally; fine to read the wall clock here
    if args.days:
        dates = [(today + dt.timedelta(days=i)).isoformat() for i in range(args.days)]
    else:
        dates = [args.date or today.isoformat()]

    api_key = os.environ.get("JINA_API_KEY")
    cache = None if args.no_cache else Path(".cache")
    if not api_key:
        print("note: no JINA_API_KEY set — the free tier rate-limits hard (expect HTTP 429s "
              "and slow retries). Grab a free key at jina.ai and `export JINA_API_KEY=…` to "
              "go much faster.", file=sys.stderr)
        if args.concurrency > 4:
            print(f"note: lowering --concurrency {args.concurrency} → 3 (no key). "
                  "Re-runs reuse the cache + channels.json, so failed pages recover.", file=sys.stderr)
            args.concurrency = 3

    resolver = None if args.no_watch_links else ChannelResolver(cache, api_key, args.delay, args.concurrency)

    # ── Pass 1: collect matches per day, fetching match pages in parallel. ──────
    scraped: list[dict] = []
    for d in dates:
        sched_url = f"{LSTV}/schedules/{d}/"
        print(f"[{d}] schedule …", file=sys.stderr)
        try:
            matches = parse_schedule(fetch(sched_url, cache, api_key, args.delay))
        except RuntimeError as e:
            print(f"  ! {e}", file=sys.stderr)
            continue
        matches = [m for m in matches if m["has_tv"]]
        if args.limit:
            matches = matches[: args.limit]
        print(f"  {len(matches)} matches with TV — fetching ({args.concurrency}-way)…", file=sys.stderr)

        def scrape_match(m: dict) -> dict | None:
            try:
                broadcasts = parse_match(fetch(m["url"], cache, api_key, args.delay))
            except RuntimeError as e:
                print(f"  ! {m['home']} v {m['away']}: {e}", file=sys.stderr)
                return None
            return {
                "date": d, "home": m["home"], "away": m["away"],
                "timeText": m["time_text"], "sourceUrl": m["url"], "broadcasts": broadcasts,
            }

        with ThreadPoolExecutor(max_workers=args.concurrency) as pool:
            for res in pool.map(scrape_match, matches):
                if res:
                    scraped.append(res)
        print(f"  {sum(1 for s in scraped if s['date'] == d)} matches scraped", file=sys.stderr)

    # ── Pass 2: resolve every unique channel's watch URL once, in parallel, ─────
    # then attach to each broadcaster and drop the internal slug.
    if resolver:
        slugs = {b.get("_slug") for s in scraped for e in s["broadcasts"] for b in e["broadcasters"]}
        resolver.resolve_all(slugs)
    for s in scraped:
        for e in s["broadcasts"]:
            for b in e["broadcasters"]:
                slug = b.pop("_slug", None)
                if resolver:
                    b["url"] = resolver.website(slug)

    Path(args.out).write_text(json.dumps(scraped, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nwrote {len(scraped)} matches → {args.out}", file=sys.stderr)

    fixtures = load_fixtures(args, dates)
    if fixtures is not None:
        mapped = match_fixtures(scraped, fixtures)
        Path(args.mapped_out).write_text(json.dumps(mapped, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"matched {len(mapped)}/{len(fixtures)} fixtures → {args.mapped_out}", file=sys.stderr)

        if args.ingest_url:
            if not args.ingest_key:
                print("! --ingest-url given but no --ingest-key / SCRAPER_INGEST_KEY", file=sys.stderr)
                return 1
            if not mapped:
                print("! nothing matched — skipping ingest.", file=sys.stderr)
                return 1
            r = requests.post(
                args.ingest_url,
                json={"fixtures": mapped},
                headers={"x-ingest-key": args.ingest_key, "Content-Type": "application/json"},
                timeout=60,
            )
            print(f"ingest → {args.ingest_url}: HTTP {r.status_code} {r.text[:200]}", file=sys.stderr)
            return 0 if r.ok else 1
    elif args.ingest_url:
        print("! --ingest-url needs fixtures (--fixtures-api or --fixtures) to map IDs; skipped.", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
