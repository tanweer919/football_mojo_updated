import { MatchStatus } from '@prisma/client';

/**
 * api-football fixture status codes:
 *   NS=Not Started · TBD=Time TBD · 1H=First Half · HT=Halftime · 2H=Second Half
 *   ET=Extra Time · BT=Break (before ET) · P=Penalty Shootout · LIVE=Live (no detail)
 *   FT=Full Time · AET=After ET · PEN=After Penalties
 *   PST=Postponed · SUSP=Suspended · INT=Interrupted
 *   CANC/ABD/AWD/WO=Cancelled / abandoned / awarded / walkover
 *
 * Maps to our internal MatchStatus enum. Keep this single source of truth —
 * both the realtime poller AND the seed depend on identical mapping.
 */
export function mapApiFootballStatus(short: string): MatchStatus {
  switch (short) {
    case 'NS':
    case 'TBD':
      return 'SCHEDULED';

    case '1H':
    case '2H':
    case 'LIVE':
    case 'ET':
    case 'P':
    case 'BT':
    case 'SUSP':
    case 'INT':
      return 'LIVE';

    case 'HT':
      return 'HALF_TIME';

    case 'FT':
    case 'AET':
    case 'PEN':
      return 'FINISHED';

    case 'PST':
      return 'POSTPONED';

    case 'CANC':
    case 'ABD':
    case 'AWD':
    case 'WO':
      return 'CANCELLED';

    default:
      return 'SCHEDULED';
  }
}

/** Statuses where the match is currently being played. */
export function isLiveApiFootballStatus(short: string): boolean {
  return ['1H', '2H', 'HT', 'ET', 'BT', 'P', 'LIVE', 'SUSP', 'INT'].includes(short);
}
