/**
 * Evergreen league registry — these pages keep the site earning traffic after
 * the World Cup. Each maps a URL slug to a backend competition-name matcher and
 * localized-leaning copy. Mirrors the Play listing's evergreen (league-led)
 * positioning. `nameMatch` filters the all-competitions fixtures feed.
 */
export interface LeagueDef {
  slug: string;
  name: string;          // display
  short: string;         // H1 lead term
  nameMatch: RegExp;     // backend competition.name matcher
  blurb: string;         // intro paragraph (keyword-aware, natural)
  region?: string;
}

export const LEAGUES: LeagueDef[] = [
  {
    slug: 'premier-league',
    name: 'Premier League',
    short: 'Premier League',
    nameMatch: /premier league/i,
    blurb:
      'Premier League fixtures, results and live scores, plus the latest table and AI match previews — free, with no betting or gambling.',
  },
  {
    slug: 'champions-league',
    name: 'UEFA Champions League',
    short: 'Champions League',
    nameMatch: /champions league/i,
    blurb:
      'UEFA Champions League fixtures, live scores, group/league phase tables and knockout bracket, with AI previews and recaps — completely free.',
  },
  {
    slug: 'la-liga',
    name: 'LaLiga',
    short: 'LaLiga',
    nameMatch: /la ?liga/i,
    blurb: 'LaLiga fixtures, results, live scores and standings, with AI match previews — free and family-safe, no betting.',
  },
  {
    slug: 'serie-a',
    name: 'Serie A',
    short: 'Serie A',
    nameMatch: /serie a/i,
    blurb: 'Serie A fixtures, live scores, results and the latest classifica, plus AI previews and recaps — free, no gambling.',
  },
  {
    slug: 'bundesliga',
    name: 'Bundesliga',
    short: 'Bundesliga',
    nameMatch: /bundesliga/i,
    blurb: 'Bundesliga fixtures, live scores, results and tables (Tabellen), with AI summaries — kostenlos und werbefreundlich, ohne Wetten.',
  },
  {
    slug: 'isl',
    name: 'Indian Super League',
    short: 'ISL',
    nameMatch: /indian super league|\bisl\b/i,
    blurb: 'Indian Super League (ISL) fixtures, live scores, results and standings — free football scores for Indian fans, no betting.',
    region: 'India',
  },
  {
    slug: 'i-league',
    name: 'I-League',
    short: 'I-League',
    nameMatch: /i-?league/i,
    blurb: 'I-League fixtures, live scores, results and table for Indian football fans — free, family-safe, no gambling.',
    region: 'India',
  },
];

export const leagueBySlug = (slug: string) => LEAGUES.find((l) => l.slug === slug);
