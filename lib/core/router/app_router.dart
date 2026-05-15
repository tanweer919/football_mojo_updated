import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/album/presentation/screens/album_screen.dart';
import '../../features/album/presentation/screens/card_detail_screen.dart';
import '../../features/fantasy/presentation/screens/fantasy_home_screen.dart';
import '../../features/fantasy/presentation/screens/fantasy_leaderboard_screen.dart';
import '../../features/fantasy/presentation/screens/lineup_builder_screen.dart';
import '../../features/fantasy/presentation/screens/player_breakdown_screen.dart';
import '../../features/fantasy/presentation/screens/scoring_rules_screen.dart';
import '../../features/iap/presentation/screens/pro_paywall_screen.dart';
import '../../features/insights/presentation/screens/injuries_screen.dart';
import '../../features/global_cup/presentation/screens/global_cup_screen.dart';
import '../../features/player/presentation/screens/player_profile_screen.dart';
import '../../features/h2h/presentation/screens/h2h_screen.dart';
import '../../features/home/presentation/screens/home_dashboard_screen.dart';
import '../../features/home/presentation/screens/home_shell.dart';
import '../../features/matches/presentation/screens/match_detail_screen.dart';
import '../../features/matches/presentation/screens/matches_screen.dart';
import '../../features/news/presentation/screens/news_reader_screen.dart';
import '../../features/news/presentation/screens/news_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/predictions/presentation/screens/predictions_leaderboard_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/today/presentation/screens/today_screen.dart';
import '../../features/tournament/presentation/screens/bracket_screen.dart';
import '../../features/world_cup/presentation/screens/world_cup_screen.dart';
import '../auth/auth_providers.dart';
import '../bootstrap/deferred_bootstrap.dart';
import 'route_paths.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(onboardingCompleteProvider);

  return GoRouter(
    initialLocation: RoutePaths.home,
    refreshListenable: GoRouterRefreshNotifier(ref),
    // Microsoft Clarity tracks screen-name changes via this observer.
    // Safe to register before the SDK is initialised — calls queue.
    observers: [clarityService.routeObserver],
    redirect: (ctx, state) {
      final path = state.matchedLocation;
      final completedOnboarding = auth.maybeWhen(data: (v) => v, orElse: () => true);
      final isOnboarding = path == RoutePaths.onboarding;
      if (!completedOnboarding && !isOnboarding) return RoutePaths.onboarding;
      if (completedOnboarding && isOnboarding) return RoutePaths.home;
      return null;
    },
    routes: [
      GoRoute(path: RoutePaths.onboarding, builder: (_, __) => const OnboardingScreen()),

      ShellRoute(
        builder: (ctx, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: RoutePaths.home,        builder: (_, __) => const HomeDashboardScreen()),
          GoRoute(path: RoutePaths.matches,     builder: (_, __) => const MatchesScreen()),
          GoRoute(path: RoutePaths.fantasyHome, builder: (_, __) => const FantasyHomeScreen()),
          GoRoute(path: RoutePaths.album,       builder: (_, __) => const AlbumScreen()),
          GoRoute(path: RoutePaths.news,        builder: (_, __) => const NewsScreen()),
          GoRoute(path: RoutePaths.tournament,  builder: (_, __) => const WorldCupScreen()),
          // Legacy "Today" tab — routable but no longer in nav.
          GoRoute(path: RoutePaths.today,       builder: (_, __) => const TodayScreen()),
        ],
      ),

      // Detail
      GoRoute(path: RoutePaths.matchDetail, builder: (_, s) => MatchDetailScreen(matchId: s.pathParameters['id']!)),
      GoRoute(path: RoutePaths.newsReader,  builder: (_, s) => NewsReaderScreen(articleId: s.pathParameters['id']!)),
      GoRoute(path: RoutePaths.cardDetail,  builder: (_, s) => CardDetailScreen(ownedCardId: s.pathParameters['id']!)),
      GoRoute(path: RoutePaths.profile,     builder: (_, __) => const ProfileScreen()),
      GoRoute(path: RoutePaths.settings,    builder: (_, __) => const SettingsScreen()),
      GoRoute(path: RoutePaths.bracket,     builder: (_, __) => const BracketScreen()),

      // Fantasy / Global Cup / H2H
      GoRoute(
        path: RoutePaths.fantasyTournament,
        builder: (_, s) => FantasyHomeScreen(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: RoutePaths.lineupBuilder,
        builder: (_, s) => LineupBuilderScreen(
          slug: s.pathParameters['slug']!,
          gameweekId: s.pathParameters['gwId']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.fantasyLeaderboard,
        builder: (_, s) => FantasyLeaderboardScreen(
          slug: s.pathParameters['slug']!,
          gameweekId: s.pathParameters['gwId']!,
        ),
      ),
      GoRoute(
        path: RoutePaths.globalCup,
        builder: (_, s) => GlobalCupScreen(tournamentId: s.pathParameters['tournamentId']!),
      ),
      GoRoute(path: RoutePaths.h2h, builder: (_, __) => const H2HScreen()),
      GoRoute(path: RoutePaths.predictionsBoard, builder: (_, __) => const PredictionsLeaderboardScreen()),
      GoRoute(path: RoutePaths.scoringRules, builder: (_, __) => const ScoringRulesScreen()),
      GoRoute(
        path: RoutePaths.playerBreakdown,
        builder: (_, s) => PlayerBreakdownScreen(
          gameweekId: s.pathParameters['gwId']!,
          playerId: s.pathParameters['playerId']!,
        ),
      ),
      GoRoute(path: RoutePaths.injuries,    builder: (_, __) => const InjuriesScreen()),
      GoRoute(path: RoutePaths.proPaywall,  builder: (_, __) => const ProPaywallScreen()),
      GoRoute(
        path: RoutePaths.playerProfile,
        builder: (_, s) => PlayerProfileScreen(playerId: s.pathParameters['id']!),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.matchedLocation}')),
    ),
  );
});

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen(onboardingCompleteProvider, (_, __) => notifyListeners());
  }
}
