// Sorare-style scoring rules. Three transparent buckets per player per match:
//   - All-Around  (max 50, can go negative on bad performances)
//   - Decisive    (max 25, can go negative)
//   - Position    (max 25)
// Total clamped to [-20, 100]. Captain x2 applied at lineup roll-up.
//
// Position weights are derived from how meaningful each action is for that role
// (defenders aren't penalised for low passing volume; forwards earn outsized
// rewards from key passes than from defensive duels, etc.).
//
// Skipped from Sorare's published rules:
//   - Competition coefficients   (we score one tournament at a time)
//   - "Error leading to goal"    (not in api-football payload)
//
// All field names below match the api-football `/fixtures/players` payload.

import { PlayerPosition } from '@prisma/client';

/// 5-a-side format. The fifth slot is a "Utility" pick that can be DEF / MID
/// / FWD — so we enforce a *minimum* per outfield position and exactly 1 GK,
/// with total = 5. (See submitLineup in fantasy.service.ts.)
export const SQUAD = {
  size: 5,
  exactGK: 1,
  /// Each non-GK outfield position must appear at least this many times.
  /// The 5th pick (the UTL slot) is free to pick any of DEF/MID/FWD.
  minByPosition: { DEF: 1, MID: 1, FWD: 1 } as Record<'DEF' | 'MID' | 'FWD', number>,
  budget: 100,
} as const;

export type Bucket = 'allAround' | 'decisive' | 'position';

export interface BreakdownEntry {
  key: string;          // 'goal' | 'assist' | 'pass.completed' | ...
  bucket: Bucket;
  label: string;        // human-readable for the UI
  count: number;        // how many of this event occurred
  points: number;       // points contributed (may be negative)
}

// ─── All-Around: volume actions, position-weighted ────────────────────────────
// Each action contributes `weight × count`, capped by a per-position max.
export const ALL_AROUND_WEIGHTS: Record<PlayerPosition, Record<string, number>> = {
  GK:  { pass: 0.05, accurate_pass_bonus: 2,  duel_won: 0.4 },
  DEF: { pass: 0.04, accurate_pass_bonus: 2,  duel_won: 0.5, foul_drawn: 0.3, foul_committed: -0.4, offside: -0.5 },
  MID: { pass: 0.05, accurate_pass_bonus: 3,  duel_won: 0.5, foul_drawn: 0.3, foul_committed: -0.4, offside: -0.3 },
  FWD: { pass: 0.06, accurate_pass_bonus: 3,  duel_won: 0.4, foul_drawn: 0.4, foul_committed: -0.3, offside: -0.4 },
};
export const ALL_AROUND_CAP = 50;

// ─── Decisive: moments that change games ───────────────────────────────────────
export const DECISIVE = {
  goal:        { GK: 12, DEF: 10, MID: 9,  FWD: 8 } as Record<PlayerPosition, number>,
  assist:      { GK:  6, DEF:  6, MID: 6,  FWD: 6 } as Record<PlayerPosition, number>,
  penaltyGoal: { GK:  9, DEF:  7, MID: 6,  FWD: 5 } as Record<PlayerPosition, number>,
  cleanSheet:  { GK:  8, DEF:  6, MID: 2,  FWD: 0 } as Record<PlayerPosition, number>,
  twoConceded: { GK: -3, DEF: -2, MID:  0, FWD: 0 } as Record<PlayerPosition, number>,
  ownGoal:     -5,
  redCard:     -6,
  yellowCard:  -1,
  penaltyMiss: -4,
  penaltyWon:   2,
  penaltyCommit: -3,
  cap: 25,
  floor: -25,
};

// ─── Position-specific bucket ─────────────────────────────────────────────────
export const POSITION_RULES = {
  GK:  { savePerOne: 1.0, penaltySave: 6, conceded: -0.8 },
  DEF: { block: 1.2, interception: 1.0, duelWon: 0.4, tackle: 0.7 },
  MID: { keyPass: 1.5, completedPass: 0.04, successfulDribble: 1.0, tackle: 0.5 },
  FWD: { shotOnTarget: 1.6, shotBlockedByDef: 0.5, successfulDribble: 1.0, keyPass: 1.2 },
  cap: 25,
} as const;

export const APPEARANCE_POINTS = {
  played:   1,            // ≥1 minute
  played60: 2,            // ≥60 minutes
};

export const CAPTAIN_MULTIPLIER = 2;

export const SCORE_FLOOR = -20;
export const SCORE_CEILING = 100;

export const PRICING = {
  defaultPrice: 5.0,
  minPrice:     4.0,
  maxPrice:    14.5,
  formWindow:   5,
  formWeight:   0.7,
};
