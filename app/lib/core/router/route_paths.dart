/// Centralised route paths so screens never hardcode strings.
class RoutePaths {
  static const splash      = '/';
  static const onboarding  = '/onboarding';
  static const signIn      = '/sign-in';

  // Tab shell
  static const home        = '/home';      // home dashboard (new default)
  static const today       = '/today';     // matches/today (legacy tab, kept for live focus)
  static const matches     = '/matches';
  static const tournament  = '/tournament';
  static const news        = '/news';
  static const album       = '/album';
  static const market      = '/market';
  static const shop        = '/shop';       // gem shop: bundles + single cards
  static const profile     = '/profile';

  // Highlights — list screen; individual highlights open in the YouTube app.
  static const highlights  = '/highlights';

  // Detail
  static const matchDetail = '/matches/:id';
  static const newsReader  = '/news/:id';
  static const cardDetail  = '/album/:id';
  static const cardStats   = '/album/:id/stats';
  static const marketCard  = '/market/:templateId';
  static const settings    = '/settings';
  static const bracket            = '/tournament/bracket';
  static const bracketLeaderboard = '/tournament/bracket/leaderboard';
  static const bracketUser        = '/tournament/bracket/user/:userId';

  // Fantasy / Global Cup / H2H
  static const fantasyHome        = '/fantasy';
  static const fantasyTournament  = '/fantasy/:slug';
  static const lineupBuilder      = '/fantasy/:slug/gameweek/:gwId/builder';
  static const fantasyLeaderboard = '/fantasy/:slug/gameweek/:gwId/leaderboard';
  static const fantasyLeagues     = '/fantasy/:slug/leagues';
  static const globalCup          = '/global-cup/:tournamentId';
  static const h2h                = '/h2h';
  static const h2hLadder          = '/h2h/ladder';
  static const h2hInvite          = '/h2h/i/:token';
  static const predictionsBoard   = '/predictions/leaderboard';
  static const scoringRules       = '/scoring/rules';
  static const playerBreakdown    = '/scoring/breakdown/:gwId/:playerId';

  // Insights
  static const injuries           = '/insights/injuries';
  static const playerProfile      = '/players/:id';
  static const standings          = '/wc/standings';
  static const topScorers         = '/wc/top-scorers';

  // Following
  static const teamPicker         = '/following/pick';
  static const myTeam             = '/my-team';

  // IAP
  static const proPaywall         = '/pro';
  static const wallet             = '/wallet';

  // Profile sub-screens
  static const notificationPrefs   = '/profile/notifications';
  static const notificationCenter  = '/profile/inbox';
  static const supportedCountry    = '/profile/country';

  // Award pick'em
  static const awardPicks         = '/tournament/awards';

  // Static legal / support pages
  static const privacyPolicy      = '/legal/privacy';
  static const termsOfService     = '/legal/terms';
  static const helpCentre         = '/help';
}
