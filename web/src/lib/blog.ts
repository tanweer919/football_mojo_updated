/**
 * Cornerstone blog posts. Kept as structured data (not MDX) for the first pass
 * so it ships with zero new deps; swap the `body` renderer for MDX later if you
 * want rich authoring. Each post internally links the WC hub + Play CTA.
 */
export type Block =
  | { t: 'p'; text: string }
  | { t: 'h2'; text: string }
  | { t: 'ul'; items: string[] };

export interface Post {
  slug: string;
  title: string;        // ≤60 ideal
  description: string;  // ≤155
  date: string;         // ISO
  body: Block[];
}

export const POSTS: Post[] = [
  {
    slug: 'how-to-watch-world-cup-2026',
    title: 'How to Watch World Cup 2026: Schedule & Live Scores',
    description:
      'How to follow every FIFA World Cup 2026 match — full schedule, kick-off times, live scores and free goal alerts. No betting, no gambling.',
    date: '2026-06-20',
    body: [
      { t: 'p', text: 'The FIFA World Cup 2026 is the biggest in history: 48 teams, 104 matches, across the United States, Canada and Mexico from 11 June to 19 July. Here is how to keep up with every kick-off, goal and result for free.' },
      { t: 'h2', text: 'Follow live scores and fixtures' },
      { t: 'p', text: 'Use the FootballMojo World Cup 2026 hub for the full schedule, live scores, group standings and the knockout bracket. Kick-off times auto-convert to your timezone, and you can get instant goal, kick-off and full-time alerts in the free app.' },
      { t: 'h2', text: 'The format, briefly' },
      { t: 'ul', items: [
        'Group stage (11–27 June): 12 groups of 4, 72 matches.',
        'Top two per group plus eight best third-placed teams reach the Round of 32.',
        'Knockouts: Round of 32 → Round of 16 → quarter-finals → semi-finals → final (19 July).',
      ] },
      { t: 'h2', text: 'Why FootballMojo' },
      { t: 'p', text: 'Live scores, AI match previews and recaps, fixtures, tables and the full bracket — 100% free, family-safe, with no betting, no odds and no gambling.' },
    ],
  },
  {
    slug: 'world-cup-2026-groups-and-bracket-guide',
    title: 'World Cup 2026 Groups & Bracket Guide',
    description:
      'A clear guide to the World Cup 2026 groups, qualification rules and the knockout bracket — who advances and how the Round of 32 works.',
    date: '2026-06-18',
    body: [
      { t: 'p', text: 'For the first time, the World Cup has 12 groups of four teams. Here is how qualification and the new Round of 32 bracket work.' },
      { t: 'h2', text: 'How teams qualify from the groups' },
      { t: 'ul', items: [
        'The top two teams in each of the 12 groups advance (24 teams).',
        'The eight best third-placed teams also advance.',
        'That gives 32 teams for the Round of 32.',
      ] },
      { t: 'h2', text: 'The knockout bracket' },
      { t: 'p', text: 'From the Round of 32 it is single-elimination: Round of 16, quarter-finals, semi-finals, the third-place match and the final on 19 July 2026. Track every tie — and predict the whole bracket — in FootballMojo.' },
    ],
  },
  {
    slug: 'best-halal-no-gambling-football-apps',
    title: 'Best Halal, No-Gambling Football Apps (2026)',
    description:
      'Looking for a football scores app with no betting or gambling? Here are the best halal, family-safe options for live scores and the World Cup 2026.',
    date: '2026-06-15',
    body: [
      { t: 'p', text: 'Most football apps push betting odds and gambling promos. If you want clean, family-safe live scores — for the World Cup 2026 or year-round leagues — here is what to look for and our pick.' },
      { t: 'h2', text: 'What "halal / no-gambling" should mean' },
      { t: 'ul', items: [
        'No betting tips, no odds, no bookmaker integrations.',
        'No gambling ads or sponsorships.',
        'Family-safe content and a transparent, free model.',
      ] },
      { t: 'h2', text: 'FootballMojo' },
      { t: 'p', text: 'FootballMojo is built halal-first: live scores, World Cup 2026 fixtures and bracket, fantasy, and AI previews & recaps — with no betting, no odds and no gambling, free on Google Play.' },
    ],
  },
];

export const postBySlug = (slug: string) => POSTS.find((p) => p.slug === slug);
