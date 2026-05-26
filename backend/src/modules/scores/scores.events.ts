// Wire format for WebSocket payloads + Redis pub/sub channels.
// Keep these stable — Flutter clients depend on them.

import { MatchStatus, EventType } from '@prisma/client';

export const CHANNELS = {
  matchUpdate: (id: string) => `match:${id}:update`,
  matchEvent:  (id: string) => `match:${id}:event`,
  fixturesUpdate:           'fixtures:update',
} as const;

export interface MatchUpdatePayload {
  id: string;
  status: MatchStatus;
  minute: number | null;
  homeScore: number;
  awayScore: number;
  homePenalties: number | null;
  awayPenalties: number | null;
  updatedAt: string;
}

export interface MatchEventPayload {
  id: string;
  matchId: string;
  minute: number;
  type: EventType;
  teamId: string | null;
  playerId: string | null;
  detail: string | null;
  createdAt: string;
}
