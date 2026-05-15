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
  static const profile     = '/profile';

  // Detail
  static const matchDetail = '/matches/:id';
  static const newsReader  = '/news/:id';
  static const cardDetail  = '/album/:id';
  static const settings    = '/settings';
  static const bracket     = '/tournament/bracket';

  // Fantasy / Global Cup / H2H
  static const fantasyHome        = '/fantasy';
  static const fantasyTournament  = '/fantasy/:slug';
  static const lineupBuilder      = '/fantasy/:slug/gameweek/:gwId/builder';
  static const fantasyLeaderboard = '/fantasy/:slug/gameweek/:gwId/leaderboard';
  static const globalCup          = '/global-cup/:tournamentId';
  static const h2h                = '/h2h';
  static const predictionsBoard   = '/predictions/leaderboard';
  static const scoringRules       = '/scoring/rules';
  static const playerBreakdown    = '/scoring/breakdown/:gwId/:playerId';

  // Insights
  static const injuries           = '/insights/injuries';
  static const playerProfile      = '/players/:id';

  // IAP
  static const proPaywall         = '/pro';
}
