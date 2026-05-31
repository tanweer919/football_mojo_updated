/**
 * Shared Prisma `where` clause fragments for excluding synthetic placeholder
 * teams from client-facing queries.
 *
 * Placeholder teams are created by `seed-wc-2026.ts` for knockout bracket
 * slots (e.g. "A2", "W74", "3rd A/B/C/D/F") and for real countries whose
 * Team row didn't exist at seed time (e.g. "WC2026-PH-BRAZIL"). They're
 * needed internally for match scheduling but should never appear in:
 *   - team search / favourites picker
 *   - group standings
 *   - followed-teams list
 *   - team counts surfaced to the client
 *
 * The constant below is a Prisma `where` fragment you can spread into any
 * `findMany` / `count` call:
 *
 *   this.prisma.team.findMany({
 *     where: { ...EXCLUDE_PLACEHOLDER_TEAMS, competitionId: 'WC2026' },
 *   })
 */

/** Prisma `where` clause that excludes synthetic WC2026 placeholder teams. */
export const EXCLUDE_PLACEHOLDER_TEAMS = {
  NOT: { id: { startsWith: 'WC2026-PH-' } },
} as const;

/**
 * Same filter but shaped for use inside a nested `include` on a relation.
 * Use when you need to filter the team side of a join (e.g. GroupStanding
 * includes team — you want to flag which standings are placeholder-based
 * but can't filter them at the join level in Prisma).
 */
export function isPlaceholderTeamId(id: string): boolean {
  return id.startsWith('WC2026-PH-');
}
