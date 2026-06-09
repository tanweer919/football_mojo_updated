/**
 * Canonical World Cup 2026 nation names → every label api-football may use for
 * them. This is the single source of truth shared by:
 *   - the WC seed (`prisma/seed-wc-2026.ts`), which writes the CANONICAL name
 *     onto its placeholder team rows, and
 *   - the live ingest (`scores.service.ts`), which reconciles an incoming
 *     api-football fixture back to the seeded row so we don't keep duplicates.
 *
 * Keep the canonical key identical to the seed's display/group name.
 */
export const WC_TEAM_ALIASES: Record<string, string[]> = {
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

/** Lower-case, strip diacritics + non-alphanumerics for robust comparison. */
export function normalizeTeamName(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '') // strip combining diacritics
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

// Reverse index: any normalized alias (and the canonical itself) → canonical.
const _toCanonical: Record<string, string> = (() => {
  const m: Record<string, string> = {};
  for (const [canonical, aliases] of Object.entries(WC_TEAM_ALIASES)) {
    m[normalizeTeamName(canonical)] = canonical;
    for (const a of aliases) m[normalizeTeamName(a)] = canonical;
  }
  return m;
})();

/**
 * Map whatever label a source uses to the canonical seeded nation name.
 * Unknown names pass through unchanged (so non-WC fixtures are unaffected).
 */
export function canonicalTeamName(name: string): string {
  return _toCanonical[normalizeTeamName(name)] ?? name;
}

/** Order-independent canonical key for a fixture's two teams. */
export function fixturePairKey(homeName: string, awayName: string): string {
  return [canonicalTeamName(homeName), canonicalTeamName(awayName)]
    .map(normalizeTeamName)
    .sort()
    .join('|');
}
