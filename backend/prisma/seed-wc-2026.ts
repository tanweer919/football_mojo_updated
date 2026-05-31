/**
 * Seed the FIFA World Cup 2026 group draw + every official fixture.
 *
 * What this writes:
 *   - 12 Group rows (A → L) under competition `WC2026`
 *   - 48 GroupStanding rows (4 teams per group) — counters start at 0
 *   - 72 group-stage Match rows (each team plays 3) with venue + matchday
 *   - 32 knockout placeholder Match rows (R32 → Final) with venue + date,
 *     using the existing `Team` rows where the side is already known and
 *     the synthetic placeholder TBD teams (`WC2026-TBD-*`) where it isn't.
 *
 * Idempotent. Re-run any time after `seed:roster` (which provides the team rows).
 *
 * Run: `npm run seed:wc`
 *
 * Why a separate script:
 *   - The schedule is published once in Dec 2025 and never changes — no need
 *     to refetch from api-football repeatedly.
 *   - Many group teams are placeholders (winners of qualifying play-offs)
 *     that api-football won't fully resolve until late spring 2026.
 *   - Hard-coding lets the app render the bracket + venue map immediately
 *     without waiting for upstream catch-up.
 */

import { PrismaClient } from '@prisma/client';
import 'dotenv/config';

const prisma = new PrismaClient();

const COMPETITION_ID = 'WC2026';

// ─── Team aliases ────────────────────────────────────────────────────────────
// api-football uses team ids; we look up by name. If a team isn't in the DB
// yet we create a synthetic placeholder with id = `WC2026-PH-{slug}`.
//
// Synthetic placeholder ids start with `WC2026-PH-` so the poller can
// recognise them and replace with the real api-football id when the squad
// finalises. Used for play-off winners, knockout-stage TBD slots, etc.
const SYNTHETIC_PREFIX = 'WC2026-PH-';

// Teams that are publicly named in the draw (no play-off variants).
// (Synonyms: when api-football uses a different label, list them here.)
const TEAM_ALIASES: Record<string, string[]> = {
  'Mexico': ['Mexico'],
  'South Africa': ['South Africa'],
  'Korea Republic': ['South Korea', 'Korea Republic'],
  'Czechia': ['Czech Republic', 'Czechia'],
  'Canada': ['Canada'],
  'Bosnia and Herzegovina': ['Bosnia & Herzegovina', 'Bosnia and Herzegovina'],
  'Qatar': ['Qatar'],
  'Switzerland': ['Switzerland'],
  'Brazil': ['Brazil'],
  'Morocco': ['Morocco'],
  'Haiti': ['Haiti'],
  'Scotland': ['Scotland'],
  'USA': ['United States', 'USA'],
  'Paraguay': ['Paraguay'],
  'Australia': ['Australia'],
  'Türkiye': ['Turkey', 'Türkiye'],
  'Germany': ['Germany'],
  'Curaçao': ['Curacao', 'Curaçao'],
  "Côte d'Ivoire": ['Ivory Coast', "Côte d'Ivoire"],
  'Ecuador': ['Ecuador'],
  'Netherlands': ['Netherlands'],
  'Japan': ['Japan'],
  'Sweden': ['Sweden'],
  'Tunisia': ['Tunisia'],
  'Saudi Arabia': ['Saudi Arabia'],
  'Uruguay': ['Uruguay'],
  'Spain': ['Spain'],
  'Cabo Verde': ['Cape Verde Islands', 'Cape Verde', 'Cabo Verde'],
  'IR Iran': ['Iran', 'IR Iran'],
  'New Zealand': ['New Zealand'],
  'Belgium': ['Belgium'],
  'Egypt': ['Egypt'],
  'France': ['France'],
  'Senegal': ['Senegal'],
  'Iraq': ['Iraq'],
  'Norway': ['Norway'],
  'Argentina': ['Argentina'],
  'Algeria': ['Algeria'],
  'Austria': ['Austria'],
  'Jordan': ['Jordan'],
  'Ghana': ['Ghana'],
  'Panama': ['Panama'],
  'England': ['England'],
  'Croatia': ['Croatia'],
  'Portugal': ['Portugal'],
  'Congo DR': ['DR Congo', 'Congo DR'],
  'Uzbekistan': ['Uzbekistan'],
  'Colombia': ['Colombia'],
};

async function resolveTeamId(displayName: string): Promise<string> {
  const aliases = TEAM_ALIASES[displayName] ?? [displayName];
  // 1. Try exact match against any alias.
  const found = await prisma.team.findFirst({
    where: { name: { in: aliases } },
    select: { id: true },
  });
  if (found) return found.id;

  // 2. Fall back to a synthetic placeholder so we can still render the fixture.
  const syntheticId =
    SYNTHETIC_PREFIX + displayName.replace(/[^a-zA-Z0-9]/g, '-').toUpperCase();
  await prisma.team.upsert({
    where: { id: syntheticId },
    create: {
      id: syntheticId,
      competitionId: COMPETITION_ID,
      name: displayName,
      shortName: displayName.slice(0, 3).toUpperCase(),
      countryCode: null,
      crestUrl: null,
    },
    update: { name: displayName, competitionId: COMPETITION_ID },
  });
  console.log(`  · placeholder team: ${displayName} → ${syntheticId}`);
  return syntheticId;
}

// ─── Group draw ──────────────────────────────────────────────────────────────
// 12 groups × 4 teams. Where api-football doesn't yet have a finalised entrant
// (e.g. the inter-confederation play-off winner), we use a descriptive label.
const GROUPS: Record<string, string[]> = {
  'A': ['Mexico', 'South Africa', 'Korea Republic', 'Czechia'],
  'B': ['Canada', 'Bosnia and Herzegovina', 'Qatar', 'Switzerland'],
  'C': ['Brazil', 'Morocco', 'Haiti', 'Scotland'],
  'D': ['USA', 'Paraguay', 'Australia', 'Türkiye'],
  'E': ['Germany', 'Curaçao', "Côte d'Ivoire", 'Ecuador'],
  'F': ['Netherlands', 'Japan', 'Sweden', 'Tunisia'],
  'G': ['Belgium', 'Egypt', 'IR Iran', 'New Zealand'],
  'H': ['Spain', 'Cabo Verde', 'Saudi Arabia', 'Uruguay'],
  'I': ['France', 'Senegal', 'Iraq', 'Norway'],
  'J': ['Argentina', 'Algeria', 'Austria', 'Jordan'],
  'K': ['Portugal', 'Congo DR', 'Uzbekistan', 'Colombia'],
  'L': ['England', 'Croatia', 'Ghana', 'Panama'],
};

// ─── Group-stage fixtures ────────────────────────────────────────────────────
// `kickoffISO` is in UTC. The user-visible time is rendered in the device tz.
type Fx = { home: string; away: string; group: string; venue: string; kickoffISO: string };
const GROUP_FIXTURES: Fx[] = [
  // Matchday 1
  { home: 'Mexico',                away: 'South Africa',           group: 'A', venue: 'Estadio Azteca, Mexico City',     kickoffISO: '2026-06-11T20:00:00-05:00' },
  { home: 'Korea Republic',        away: 'Czechia',                group: 'A', venue: 'Estadio Akron, Guadalajara',     kickoffISO: '2026-06-11T17:00:00-06:00' },
  { home: 'Canada',                away: 'Bosnia and Herzegovina', group: 'B', venue: 'BMO Field, Toronto',             kickoffISO: '2026-06-12T18:00:00-04:00' },
  { home: 'USA',                   away: 'Paraguay',               group: 'D', venue: 'SoFi Stadium, Los Angeles',      kickoffISO: '2026-06-12T20:00:00-07:00' },
  { home: 'Haiti',                 away: 'Scotland',               group: 'C', venue: 'Gillette Stadium, Boston',       kickoffISO: '2026-06-13T12:00:00-04:00' },
  { home: 'Australia',             away: 'Türkiye',                group: 'D', venue: 'BC Place, Vancouver',            kickoffISO: '2026-06-13T15:00:00-07:00' },
  { home: 'Brazil',                away: 'Morocco',                group: 'C', venue: 'MetLife Stadium, NJ/NY',         kickoffISO: '2026-06-13T18:00:00-04:00' },
  { home: 'Qatar',                 away: 'Switzerland',            group: 'B', venue: "Levi's Stadium, San Francisco",  kickoffISO: '2026-06-13T15:00:00-07:00' },
  { home: "Côte d'Ivoire",         away: 'Ecuador',                group: 'E', venue: 'Lincoln Financial, Philadelphia',kickoffISO: '2026-06-14T12:00:00-04:00' },
  { home: 'Germany',               away: 'Curaçao',                group: 'E', venue: 'NRG Stadium, Houston',           kickoffISO: '2026-06-14T15:00:00-05:00' },
  { home: 'Netherlands',           away: 'Japan',                  group: 'F', venue: 'AT&T Stadium, Dallas',           kickoffISO: '2026-06-14T18:00:00-05:00' },
  { home: 'Sweden',                away: 'Tunisia',                group: 'F', venue: 'Estadio BBVA, Monterrey',        kickoffISO: '2026-06-14T21:00:00-06:00' },
  { home: 'Saudi Arabia',          away: 'Uruguay',                group: 'H', venue: 'Hard Rock Stadium, Miami',       kickoffISO: '2026-06-15T12:00:00-04:00' },
  { home: 'Spain',                 away: 'Cabo Verde',             group: 'H', venue: 'Mercedes-Benz Stadium, Atlanta', kickoffISO: '2026-06-15T15:00:00-04:00' },
  { home: 'IR Iran',               away: 'New Zealand',            group: 'G', venue: 'SoFi Stadium, Los Angeles',      kickoffISO: '2026-06-15T15:00:00-07:00' },
  { home: 'Belgium',               away: 'Egypt',                  group: 'G', venue: 'Lumen Field, Seattle',           kickoffISO: '2026-06-15T18:00:00-07:00' },
  { home: 'France',                away: 'Senegal',                group: 'I', venue: 'MetLife Stadium, NJ/NY',         kickoffISO: '2026-06-16T15:00:00-04:00' },
  { home: 'Iraq',                  away: 'Norway',                 group: 'I', venue: 'Gillette Stadium, Boston',       kickoffISO: '2026-06-16T18:00:00-04:00' },
  { home: 'Argentina',             away: 'Algeria',                group: 'J', venue: 'Arrowhead Stadium, Kansas City', kickoffISO: '2026-06-16T15:00:00-05:00' },
  { home: 'Austria',               away: 'Jordan',                 group: 'J', venue: "Levi's Stadium, San Francisco",  kickoffISO: '2026-06-16T18:00:00-07:00' },
  { home: 'Ghana',                 away: 'Panama',                 group: 'L', venue: 'BMO Field, Toronto',             kickoffISO: '2026-06-17T12:00:00-04:00' },
  { home: 'England',               away: 'Croatia',                group: 'L', venue: 'AT&T Stadium, Dallas',           kickoffISO: '2026-06-17T15:00:00-05:00' },
  { home: 'Portugal',              away: 'Congo DR',               group: 'K', venue: 'NRG Stadium, Houston',           kickoffISO: '2026-06-17T18:00:00-05:00' },
  { home: 'Uzbekistan',            away: 'Colombia',               group: 'K', venue: 'Estadio Azteca, Mexico City',    kickoffISO: '2026-06-17T20:00:00-05:00' },

  // Matchday 2
  { home: 'Czechia',               away: 'South Africa',           group: 'A', venue: 'Mercedes-Benz Stadium, Atlanta', kickoffISO: '2026-06-18T12:00:00-04:00' },
  { home: 'Switzerland',           away: 'Bosnia and Herzegovina', group: 'B', venue: 'SoFi Stadium, Los Angeles',      kickoffISO: '2026-06-18T15:00:00-07:00' },
  { home: 'Canada',                away: 'Qatar',                  group: 'B', venue: 'BC Place, Vancouver',            kickoffISO: '2026-06-18T18:00:00-07:00' },
  { home: 'Mexico',                away: 'Korea Republic',         group: 'A', venue: 'Estadio Akron, Guadalajara',     kickoffISO: '2026-06-18T20:00:00-06:00' },
  { home: 'Brazil',                away: 'Haiti',                  group: 'C', venue: 'Lincoln Financial, Philadelphia',kickoffISO: '2026-06-19T12:00:00-04:00' },
  { home: 'Scotland',              away: 'Morocco',                group: 'C', venue: 'Gillette Stadium, Boston',       kickoffISO: '2026-06-19T15:00:00-04:00' },
  { home: 'Türkiye',               away: 'Paraguay',               group: 'D', venue: "Levi's Stadium, San Francisco",  kickoffISO: '2026-06-19T15:00:00-07:00' },
  { home: 'USA',                   away: 'Australia',              group: 'D', venue: 'Lumen Field, Seattle',           kickoffISO: '2026-06-19T18:00:00-07:00' },
  { home: 'Germany',               away: "Côte d'Ivoire",          group: 'E', venue: 'BMO Field, Toronto',             kickoffISO: '2026-06-20T12:00:00-04:00' },
  { home: 'Ecuador',               away: 'Curaçao',                group: 'E', venue: 'Arrowhead Stadium, Kansas City', kickoffISO: '2026-06-20T15:00:00-05:00' },
  { home: 'Netherlands',           away: 'Sweden',                 group: 'F', venue: 'NRG Stadium, Houston',           kickoffISO: '2026-06-20T18:00:00-05:00' },
  { home: 'Tunisia',               away: 'Japan',                  group: 'F', venue: 'Estadio BBVA, Monterrey',        kickoffISO: '2026-06-20T21:00:00-06:00' },
  { home: 'Uruguay',               away: 'Cabo Verde',             group: 'H', venue: 'Hard Rock Stadium, Miami',       kickoffISO: '2026-06-21T12:00:00-04:00' },
  { home: 'Spain',                 away: 'Saudi Arabia',           group: 'H', venue: 'Mercedes-Benz Stadium, Atlanta', kickoffISO: '2026-06-21T15:00:00-04:00' },
  { home: 'Belgium',               away: 'IR Iran',                group: 'G', venue: 'SoFi Stadium, Los Angeles',      kickoffISO: '2026-06-21T15:00:00-07:00' },
  { home: 'New Zealand',           away: 'Egypt',                  group: 'G', venue: 'BC Place, Vancouver',            kickoffISO: '2026-06-21T18:00:00-07:00' },
  { home: 'Norway',                away: 'Senegal',                group: 'I', venue: 'MetLife Stadium, NJ/NY',         kickoffISO: '2026-06-22T15:00:00-04:00' },
  { home: 'France',                away: 'Iraq',                   group: 'I', venue: 'Lincoln Financial, Philadelphia',kickoffISO: '2026-06-22T18:00:00-04:00' },
  { home: 'Argentina',             away: 'Austria',                group: 'J', venue: 'AT&T Stadium, Dallas',           kickoffISO: '2026-06-22T18:00:00-05:00' },
  { home: 'Jordan',                away: 'Algeria',                group: 'J', venue: "Levi's Stadium, San Francisco",  kickoffISO: '2026-06-22T15:00:00-07:00' },
  { home: 'England',               away: 'Ghana',                  group: 'L', venue: 'Gillette Stadium, Boston',       kickoffISO: '2026-06-23T12:00:00-04:00' },
  { home: 'Panama',                away: 'Croatia',                group: 'L', venue: 'BMO Field, Toronto',             kickoffISO: '2026-06-23T15:00:00-04:00' },
  { home: 'Portugal',              away: 'Uzbekistan',             group: 'K', venue: 'NRG Stadium, Houston',           kickoffISO: '2026-06-23T18:00:00-05:00' },
  { home: 'Colombia',              away: 'Congo DR',               group: 'K', venue: 'Estadio Akron, Guadalajara',     kickoffISO: '2026-06-23T20:00:00-06:00' },

  // Matchday 3 — group simultaneous starts (FIFA standard).
  { home: 'Scotland',              away: 'Brazil',                 group: 'C', venue: 'Hard Rock Stadium, Miami',       kickoffISO: '2026-06-24T16:00:00-04:00' },
  { home: 'Morocco',               away: 'Haiti',                  group: 'C', venue: 'Mercedes-Benz Stadium, Atlanta', kickoffISO: '2026-06-24T16:00:00-04:00' },
  { home: 'Switzerland',           away: 'Canada',                 group: 'B', venue: 'BC Place, Vancouver',            kickoffISO: '2026-06-24T13:00:00-07:00' },
  { home: 'Bosnia and Herzegovina',away: 'Qatar',                  group: 'B', venue: 'Lumen Field, Seattle',           kickoffISO: '2026-06-24T13:00:00-07:00' },
  { home: 'Czechia',               away: 'Mexico',                 group: 'A', venue: 'Estadio Azteca, Mexico City',    kickoffISO: '2026-06-24T15:00:00-05:00' },
  { home: 'South Africa',          away: 'Korea Republic',         group: 'A', venue: 'Estadio BBVA, Monterrey',        kickoffISO: '2026-06-24T15:00:00-06:00' },
  { home: 'Curaçao',               away: "Côte d'Ivoire",          group: 'E', venue: 'Lincoln Financial, Philadelphia',kickoffISO: '2026-06-25T16:00:00-04:00' },
  { home: 'Ecuador',               away: 'Germany',                group: 'E', venue: 'MetLife Stadium, NJ/NY',         kickoffISO: '2026-06-25T16:00:00-04:00' },
  { home: 'Japan',                 away: 'Sweden',                 group: 'F', venue: 'AT&T Stadium, Dallas',           kickoffISO: '2026-06-25T15:00:00-05:00' },
  { home: 'Tunisia',               away: 'Netherlands',            group: 'F', venue: 'Arrowhead Stadium, Kansas City', kickoffISO: '2026-06-25T15:00:00-05:00' },
  { home: 'Türkiye',               away: 'USA',                    group: 'D', venue: 'SoFi Stadium, Los Angeles',      kickoffISO: '2026-06-25T13:00:00-07:00' },
  { home: 'Paraguay',              away: 'Australia',              group: 'D', venue: "Levi's Stadium, San Francisco",  kickoffISO: '2026-06-25T13:00:00-07:00' },
  { home: 'Norway',                away: 'France',                 group: 'I', venue: 'Gillette Stadium, Boston',       kickoffISO: '2026-06-26T16:00:00-04:00' },
  { home: 'Senegal',               away: 'Iraq',                   group: 'I', venue: 'BMO Field, Toronto',             kickoffISO: '2026-06-26T16:00:00-04:00' },
  { home: 'Egypt',                 away: 'IR Iran',                group: 'G', venue: 'Lumen Field, Seattle',           kickoffISO: '2026-06-26T13:00:00-07:00' },
  { home: 'New Zealand',           away: 'Belgium',                group: 'G', venue: 'BC Place, Vancouver',            kickoffISO: '2026-06-26T13:00:00-07:00' },
  { home: 'Cabo Verde',            away: 'Saudi Arabia',           group: 'H', venue: 'NRG Stadium, Houston',           kickoffISO: '2026-06-26T15:00:00-05:00' },
  { home: 'Uruguay',               away: 'Spain',                  group: 'H', venue: 'Estadio Akron, Guadalajara',     kickoffISO: '2026-06-26T15:00:00-06:00' },
  { home: 'Panama',                away: 'England',                group: 'L', venue: 'MetLife Stadium, NJ/NY',         kickoffISO: '2026-06-27T16:00:00-04:00' },
  { home: 'Croatia',               away: 'Ghana',                  group: 'L', venue: 'Lincoln Financial, Philadelphia',kickoffISO: '2026-06-27T16:00:00-04:00' },
  { home: 'Algeria',               away: 'Austria',                group: 'J', venue: 'Arrowhead Stadium, Kansas City', kickoffISO: '2026-06-27T15:00:00-05:00' },
  { home: 'Jordan',                away: 'Argentina',              group: 'J', venue: 'AT&T Stadium, Dallas',           kickoffISO: '2026-06-27T15:00:00-05:00' },
  { home: 'Colombia',              away: 'Portugal',               group: 'K', venue: 'Hard Rock Stadium, Miami',       kickoffISO: '2026-06-27T16:00:00-04:00' },
  { home: 'Congo DR',              away: 'Uzbekistan',             group: 'K', venue: 'Mercedes-Benz Stadium, Atlanta', kickoffISO: '2026-06-27T16:00:00-04:00' },
];

// ─── Knockout placeholders ───────────────────────────────────────────────────
// Use synthetic team names — the poller / a future "draw" service will wire
// the real teams in once group standings finalise on 27 Jun.
type Ko = { matchNo: number; stage: string; venue: string; kickoffISO: string; home: string; away: string };
const KNOCKOUT_FIXTURES: Ko[] = [
  // R32 (28 Jun → 3 Jul)
  { matchNo: 73, stage: 'R32', kickoffISO: '2026-06-28T15:00:00-07:00', venue: 'SoFi Stadium, Los Angeles',          home: 'A2', away: 'B2' },
  { matchNo: 74, stage: 'R32', kickoffISO: '2026-06-29T15:00:00-04:00', venue: 'Gillette Stadium, Boston',           home: 'E1', away: '3rd A/B/C/D/F' },
  { matchNo: 75, stage: 'R32', kickoffISO: '2026-06-29T18:00:00-06:00', venue: 'Estadio BBVA, Monterrey',            home: 'F1', away: 'C2' },
  { matchNo: 76, stage: 'R32', kickoffISO: '2026-06-29T18:00:00-05:00', venue: 'NRG Stadium, Houston',               home: 'C1', away: 'F2' },
  { matchNo: 77, stage: 'R32', kickoffISO: '2026-06-30T15:00:00-04:00', venue: 'MetLife Stadium, NJ/NY',             home: 'I1', away: '3rd C/D/F/G/H' },
  { matchNo: 78, stage: 'R32', kickoffISO: '2026-06-30T18:00:00-05:00', venue: 'AT&T Stadium, Dallas',               home: 'E2', away: 'I2' },
  { matchNo: 79, stage: 'R32', kickoffISO: '2026-06-30T18:00:00-05:00', venue: 'Estadio Azteca, Mexico City',        home: 'A1', away: '3rd C/E/F/H/I' },
  { matchNo: 80, stage: 'R32', kickoffISO: '2026-07-01T15:00:00-04:00', venue: 'Mercedes-Benz Stadium, Atlanta',     home: 'L1', away: '3rd E/H/I/J/K' },
  { matchNo: 81, stage: 'R32', kickoffISO: '2026-07-01T15:00:00-07:00', venue: "Levi's Stadium, San Francisco",      home: 'D1', away: '3rd B/E/F/I/J' },
  { matchNo: 82, stage: 'R32', kickoffISO: '2026-07-01T18:00:00-07:00', venue: 'Lumen Field, Seattle',               home: 'G1', away: '3rd A/E/H/I/J' },
  { matchNo: 83, stage: 'R32', kickoffISO: '2026-07-02T15:00:00-04:00', venue: 'BMO Field, Toronto',                 home: 'K2', away: 'L2' },
  { matchNo: 84, stage: 'R32', kickoffISO: '2026-07-02T15:00:00-07:00', venue: 'SoFi Stadium, Los Angeles',          home: 'H1', away: 'J2' },
  { matchNo: 85, stage: 'R32', kickoffISO: '2026-07-02T18:00:00-07:00', venue: 'BC Place, Vancouver',                home: 'B1', away: '3rd E/F/G/I/J' },
  { matchNo: 86, stage: 'R32', kickoffISO: '2026-07-03T15:00:00-04:00', venue: 'Hard Rock Stadium, Miami',           home: 'J1', away: 'H2' },
  { matchNo: 87, stage: 'R32', kickoffISO: '2026-07-03T18:00:00-05:00', venue: 'Arrowhead Stadium, Kansas City',     home: 'K1', away: '3rd D/E/I/J/L' },
  { matchNo: 88, stage: 'R32', kickoffISO: '2026-07-03T18:00:00-05:00', venue: 'AT&T Stadium, Dallas',               home: 'D2', away: 'G2' },

  // R16 (4–7 Jul)
  { matchNo: 89,  stage: 'R16', kickoffISO: '2026-07-04T15:00:00-04:00', venue: 'Lincoln Financial, Philadelphia',   home: 'W74', away: 'W77' },
  { matchNo: 90,  stage: 'R16', kickoffISO: '2026-07-04T18:00:00-05:00', venue: 'NRG Stadium, Houston',              home: 'W73', away: 'W75' },
  { matchNo: 91,  stage: 'R16', kickoffISO: '2026-07-05T15:00:00-04:00', venue: 'MetLife Stadium, NJ/NY',            home: 'W76', away: 'W78' },
  { matchNo: 92,  stage: 'R16', kickoffISO: '2026-07-05T18:00:00-05:00', venue: 'Estadio Azteca, Mexico City',       home: 'W79', away: 'W80' },
  { matchNo: 93,  stage: 'R16', kickoffISO: '2026-07-06T18:00:00-05:00', venue: 'AT&T Stadium, Dallas',              home: 'W83', away: 'W84' },
  { matchNo: 94,  stage: 'R16', kickoffISO: '2026-07-06T18:00:00-07:00', venue: 'Lumen Field, Seattle',              home: 'W81', away: 'W82' },
  { matchNo: 95,  stage: 'R16', kickoffISO: '2026-07-07T15:00:00-04:00', venue: 'Mercedes-Benz Stadium, Atlanta',    home: 'W86', away: 'W88' },
  { matchNo: 96,  stage: 'R16', kickoffISO: '2026-07-07T18:00:00-07:00', venue: 'BC Place, Vancouver',               home: 'W85', away: 'W87' },

  // QF (9–11 Jul)
  { matchNo: 97,  stage: 'QF',  kickoffISO: '2026-07-09T15:00:00-04:00', venue: 'Gillette Stadium, Boston',          home: 'W89', away: 'W90' },
  { matchNo: 98,  stage: 'QF',  kickoffISO: '2026-07-10T15:00:00-07:00', venue: 'SoFi Stadium, Los Angeles',         home: 'W93', away: 'W94' },
  { matchNo: 99,  stage: 'QF',  kickoffISO: '2026-07-11T15:00:00-04:00', venue: 'Hard Rock Stadium, Miami',          home: 'W91', away: 'W92' },
  { matchNo: 100, stage: 'QF',  kickoffISO: '2026-07-11T18:00:00-05:00', venue: 'Arrowhead Stadium, Kansas City',    home: 'W95', away: 'W96' },

  // SF (14–15 Jul)
  { matchNo: 101, stage: 'SF',  kickoffISO: '2026-07-14T18:00:00-05:00', venue: 'AT&T Stadium, Dallas',              home: 'W97', away: 'W98' },
  { matchNo: 102, stage: 'SF',  kickoffISO: '2026-07-15T15:00:00-04:00', venue: 'Mercedes-Benz Stadium, Atlanta',    home: 'W99', away: 'W100' },

  // 3rd-place + Final (18–19 Jul)
  { matchNo: 103, stage: '3RD', kickoffISO: '2026-07-18T15:00:00-04:00', venue: 'Hard Rock Stadium, Miami',          home: 'L101', away: 'L102' },
  { matchNo: 104, stage: 'FINAL',kickoffISO: '2026-07-19T15:00:00-04:00',venue: 'MetLife Stadium, NJ/NY',            home: 'W101', away: 'W102' },
];

// ─── Driver ──────────────────────────────────────────────────────────────────

async function ensureCompetition() {
  await prisma.competition.upsert({
    where: { id: COMPETITION_ID },
    create: {
      id: COMPETITION_ID,
      name: 'FIFA World Cup 2026',
      type: 'tournament',
      season: '2026',
      startsAt: new Date('2026-06-11T00:00:00Z'),
      endsAt:   new Date('2026-07-19T23:59:59Z'),
      emblemUrl: 'https://media.api-sports.io/football/leagues/1.png',
    },
    update: {},
  });
}

async function seedGroups() {
  console.log('▸ Groups + standings');
  for (const [letter, teams] of Object.entries(GROUPS)) {
    const group = await prisma.group.upsert({
      where: { competitionId_name: { competitionId: COMPETITION_ID, name: `Group ${letter}` } },
      create: { competitionId: COMPETITION_ID, name: `Group ${letter}` },
      update: {},
    });
    for (let i = 0; i < teams.length; i++) {
      const teamId = await resolveTeamId(teams[i]);
      await prisma.groupStanding.upsert({
        where: { groupId_teamId: { groupId: group.id, teamId } },
        create: { groupId: group.id, teamId, position: i + 1 },
        update: { position: i + 1 },
      });
    }
    console.log(`  Group ${letter}: ${teams.join(', ')}`);
  }
}

async function seedGroupFixtures() {
  console.log('\n▸ Group-stage fixtures');
  let upserts = 0;
  for (const f of GROUP_FIXTURES) {
    const homeId = await resolveTeamId(f.home);
    const awayId = await resolveTeamId(f.away);
    // Synthetic id keeps these clearly separable from api-football fixtures
    // (whose ids are integers cast to string). Format: WC2026-{group}-{home}-{away}.
    const id = `WC2026-G${f.group}-${slug(f.home)}-${slug(f.away)}`;
    await prisma.match.upsert({
      where: { id },
      create: {
        id,
        competitionId: COMPETITION_ID,
        homeTeamId: homeId,
        awayTeamId: awayId,
        kickoffAt: new Date(f.kickoffISO),
        status: 'SCHEDULED',
        stage: `Group ${f.group}`,
        venue: f.venue,
      },
      update: {
        kickoffAt: new Date(f.kickoffISO),
        stage: `Group ${f.group}`,
        venue: f.venue,
      },
    });
    upserts++;
  }
  console.log(`  ${upserts} group-stage matches`);
}

async function seedKnockoutFixtures() {
  console.log('\n▸ Knockout placeholders');
  let upserts = 0;
  for (const f of KNOCKOUT_FIXTURES) {
    // Knockout slots use placeholder labels. The team rows are placeholders
    // until the draw resolves them.
    const homeId = await resolveTeamId(f.home);
    const awayId = await resolveTeamId(f.away);
    const id = `WC2026-${f.stage}-M${f.matchNo}`;
    const stageLabel = f.stage === 'R32' ? 'Round of 32'
      : f.stage === 'R16' ? 'Round of 16'
      : f.stage === 'QF'  ? 'Quarter-final'
      : f.stage === 'SF'  ? 'Semi-final'
      : f.stage === '3RD' ? 'Bronze final'
      : 'Final';
    await prisma.match.upsert({
      where: { id },
      create: {
        id,
        competitionId: COMPETITION_ID,
        homeTeamId: homeId,
        awayTeamId: awayId,
        kickoffAt: new Date(f.kickoffISO),
        status: 'SCHEDULED',
        stage: stageLabel,
        venue: f.venue,
      },
      update: {
        kickoffAt: new Date(f.kickoffISO),
        stage: stageLabel,
        venue: f.venue,
      },
    });
    upserts++;
  }
  console.log(`  ${upserts} knockout placeholders`);
}

function slug(s: string): string {
  return s.replace(/[^a-zA-Z0-9]/g, '').slice(0, 12).toUpperCase();
}

async function run() {
  console.log(`Seeding FIFA World Cup 2026 schedule + groups…`);
  await ensureCompetition();
  await seedGroups();
  await seedGroupFixtures();
  await seedKnockoutFixtures();
  await migrateFromPlaceholders();

  const matchCount = await prisma.match.count({ where: { competitionId: COMPETITION_ID } });
  const groupCount = await prisma.group.count({ where: { competitionId: COMPETITION_ID } });
  console.log(`\n✓ done — ${groupCount} groups · ${matchCount} matches in WC 2026`);
}

/**
 * After all groups/fixtures are seeded, check if any placeholder team
 * references can be replaced with real api-football team IDs.
 *
 * This handles the common case where `seed-wc-roster` ran after `seed-wc-2026`
 * and created real Team rows. Running `seed-wc-2026` again now migrates all
 * GroupStanding + Match rows from WC2026-PH-* to the real numeric IDs.
 */
async function migrateFromPlaceholders() {
  console.log('\n▸ Migrating placeholder team references…');
  // Find all placeholder teams
  const placeholders = await prisma.team.findMany({
    where: { id: { startsWith: SYNTHETIC_PREFIX } },
    select: { id: true, name: true },
  });
  if (!placeholders.length) {
    console.log('  No placeholders found — all teams are real.');
    return;
  }

  let migrated = 0;
  for (const ph of placeholders) {
    // Try to find a real team matching the placeholder's name
    const aliases = TEAM_ALIASES[ph.name] ?? [ph.name];
    const real = await prisma.team.findFirst({
      where: {
        name: { in: aliases },
        NOT: { id: { startsWith: SYNTHETIC_PREFIX } },
      },
      select: { id: true },
    });
    if (!real) continue;

    // Migrate GroupStanding rows
    const standingsUpdated = await prisma.groupStanding.updateMany({
      where: { teamId: ph.id },
      data: { teamId: real.id },
    });
    // Migrate Match rows (home + away)
    const homeUpdated = await prisma.match.updateMany({
      where: { homeTeamId: ph.id },
      data: { homeTeamId: real.id },
    });
    const awayUpdated = await prisma.match.updateMany({
      where: { awayTeamId: ph.id },
      data: { awayTeamId: real.id },
    });
    const total = standingsUpdated.count + homeUpdated.count + awayUpdated.count;
    if (total > 0) {
      console.log(`  ${ph.name}: ${ph.id} → ${real.id} (${total} rows)`);
      migrated += total;
    }

    // Delete the now-orphaned placeholder team
    try {
      await prisma.team.delete({ where: { id: ph.id } });
    } catch {
      // May still be referenced elsewhere — leave it
    }
  }
  console.log(`  Migrated ${migrated} references from ${placeholders.length} placeholder(s).`);
}

run()
  .catch((err) => {
    console.error('seed-wc-2026 failed:', err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());

