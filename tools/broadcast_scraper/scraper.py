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
import time
import unicodedata
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


# ───────────────────────────────────── fetch ──────────────────────────────────────
def fetch(url: str, cache: Path | None, api_key: str | None, delay: float) -> str:
    """GET a livesoccertv URL's rendered HTML via the Jina reader proxy, cached."""
    if cache:
        key = re.sub(r"[^a-z0-9]+", "_", url.lower()).strip("_") + ".html"
        cached = cache / key
        if cached.exists():
            return cached.read_text(encoding="utf-8", errors="ignore")

    headers = {"X-Return-Format": "html"}
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"

    last_err = None
    for attempt in range(3):
        try:
            r = requests.get(READER + url, headers=headers, timeout=60)
            if r.status_code == 200 and r.text:
                time.sleep(delay)  # be polite
                if cache:
                    cache.mkdir(parents=True, exist_ok=True)
                    cached.write_text(r.text, encoding="utf-8")
                return r.text
            last_err = f"HTTP {r.status_code}"
        except requests.RequestException as e:
            last_err = str(e)
        time.sleep(2 * (attempt + 1))  # backoff
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
        for a in links:
            name = a.get_text(strip=True)
            if not name or "…" in name:
                continue
            href = a.get("href", "")
            m = re.search(r"/channels/([^/]+)/?", href)
            broadcasters.append({
                "name": name,
                # Real watch URL is filled in later from the channel page's
                # "Channel Website" button (see ChannelResolver); null if none.
                "url": None,
                "logo": None,
                "_slug": m.group(1) if m else None,
            })
        if broadcasters:
            out.append({
                "country": country_to_iso2(country_name) or "",
                "countryName": country_name,
                "broadcasters": broadcasters,
            })
    return out


# ─────────────────────────── channel → watch-link resolver ────────────────────────
class ChannelResolver:
    """Resolves a livesoccertv channel slug to the broadcaster's real "Channel
    Website" watch URL (the `a.watch-button` on /channels/{slug}/). Results are
    cached on disk and reused across runs, so each channel is fetched at most
    once ever — the slug→site map is stable and shared by every fixture.
    """

    def __init__(self, cache: Path | None, api_key: str | None, delay: float):
        self.cache = cache
        self.api_key = api_key
        self.delay = delay
        self.store_path = (cache / "channels.json") if cache else None
        self.map: dict[str, str | None] = {}
        if self.store_path and self.store_path.exists():
            try:
                self.map = json.loads(self.store_path.read_text(encoding="utf-8"))
            except (ValueError, OSError):
                self.map = {}

    def website(self, slug: str | None) -> str | None:
        if not slug:
            return None
        if slug in self.map:
            return self.map[slug]
        url = f"{LSTV}/channels/{slug}/"
        site = None
        try:
            soup = BeautifulSoup(fetch(url, self.cache, self.api_key, self.delay), "html.parser")
            for a in soup.select("a.watch-button[href], a.watch-btn[href]"):
                href = a.get("href", "")
                if href.startswith("http") and "livesoccertv.com" not in href \
                        and "r.jina.ai" not in href:
                    site = href
                    break
        except RuntimeError:
            site = None
        self.map[slug] = site
        self._flush()
        return site

    def _flush(self):
        if self.store_path:
            self.store_path.parent.mkdir(parents=True, exist_ok=True)
            self.store_path.write_text(json.dumps(self.map, ensure_ascii=False, indent=0), encoding="utf-8")


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


# ─────────────────────────────────────── main ─────────────────────────────────────
def main() -> int:
    ap = argparse.ArgumentParser(description="Scrape livesoccertv where-to-watch data.")
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--date", help="single day YYYY-MM-DD (default: today)")
    g.add_argument("--days", type=int, help="scrape today .. today+N days")
    ap.add_argument("--fixtures", help="fixtures.json to map onto api-football IDs")
    ap.add_argument("--out", default="broadcasts_raw.json")
    ap.add_argument("--mapped-out", default="broadcasts_by_fixture.json")
    ap.add_argument("--no-cache", action="store_true", help="ignore on-disk HTML cache")
    ap.add_argument("--delay", type=float, default=1.5, help="seconds between requests")
    ap.add_argument("--limit", type=int, default=0, help="cap matches per day (debug)")
    ap.add_argument("--no-watch-links", action="store_true",
                    help="skip resolving each channel's real watch URL (faster, fewer fetches)")
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
        print("note: no JINA_API_KEY set — using the free tier (lower rate limits).", file=sys.stderr)

    resolver = None if args.no_watch_links else ChannelResolver(cache, api_key, args.delay)

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
        print(f"  {len(matches)} matches with TV", file=sys.stderr)
        for m in matches:
            try:
                broadcasts = parse_match(fetch(m["url"], cache, api_key, args.delay))
            except RuntimeError as e:
                print(f"  ! {m['home']} v {m['away']}: {e}", file=sys.stderr)
                continue
            # Resolve each broadcaster's real watch URL from its channel page,
            # then drop the internal slug before output.
            for entry in broadcasts:
                for b in entry["broadcasters"]:
                    slug = b.pop("_slug", None)
                    if resolver:
                        b["url"] = resolver.website(slug)
            print(f"    {m['home']} v {m['away']}: {len(broadcasts)} countries", file=sys.stderr)
            scraped.append({
                "date": d,
                "home": m["home"],
                "away": m["away"],
                "timeText": m["time_text"],
                "sourceUrl": m["url"],
                "broadcasts": broadcasts,
            })

    Path(args.out).write_text(json.dumps(scraped, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nwrote {len(scraped)} matches → {args.out}", file=sys.stderr)

    if args.fixtures:
        fixtures = json.loads(Path(args.fixtures).read_text(encoding="utf-8"))
        mapped = match_fixtures(scraped, fixtures)
        Path(args.mapped_out).write_text(json.dumps(mapped, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"matched {len(mapped)}/{len(fixtures)} fixtures → {args.mapped_out}", file=sys.stderr)

        if args.ingest_url:
            if not args.ingest_key:
                print("! --ingest-url given but no --ingest-key / SCRAPER_INGEST_KEY", file=sys.stderr)
                return 1
            r = requests.post(
                args.ingest_url,
                json={"fixtures": mapped},
                headers={"x-ingest-key": args.ingest_key, "Content-Type": "application/json"},
                timeout=60,
            )
            print(f"ingest → {args.ingest_url}: HTTP {r.status_code} {r.text[:200]}", file=sys.stderr)
            return 0 if r.ok else 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
