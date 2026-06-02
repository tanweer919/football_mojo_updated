import 'package:flutter/foundation.dart';
import 'package:chottu_link/chottu_link.dart';
import 'package:chottu_link/dynamic_link/cl_dynamic_link_behaviour.dart';
import 'package:chottu_link/dynamic_link/cl_dynamic_link_parameters.dart';
import 'package:share_plus/share_plus.dart';

/// ChottuLink service for deep linking and shareable links.
///
/// Provides:
///  - SDK initialisation + incoming-link listener
///  - Typed helpers for sharing news, players, matches, leagues
///  - Deep link parser for GoRouter integration
class ChottuLinkService {
  ChottuLinkService._();
  static final instance = ChottuLinkService._();

  // ── Configuration ────────────────────────────────────────────────────
  // TODO: Replace with your actual ChottuLink API key from the Dashboard.
  static const String _apiKey = 'c_app_0ZaLFapXc0JEN0aU472DTCz5BnJzQctp';

  // Your ChottuLink domain — set up in the Dashboard.
  static const String _domain = 'footballmojo.chottu.link';

  // Base URL for your app's deep links (must match dashboard config).
  static const String _baseUrl = 'https://footballmojo.in';

  // ── Initialisation ───────────────────────────────────────────────────

  /// Call once from `main()` **after** `WidgetsFlutterBinding.ensureInitialized()`.
  Future<void> init() async {
    try {
      await ChottuLink.init(apiKey: _apiKey);
      debugPrint('✅ ChottuLink initialised');
    } catch (e) {
      debugPrint('❌ ChottuLink init failed: $e');
    }
  }

  /// Subscribe to incoming deep links. Typically called once during
  /// app bootstrap (e.g. inside the root widget's `initState`).
  ///
  /// [onLink] receives the **full deep-link URL** (e.g.
  /// `https://footballmojo.in/news?id=abc123`). Use [parseDeepLink] to
  /// extract the route + params and push via GoRouter.
  void listenForLinks(void Function(String link) onLink) {
    ChottuLink.onLinkReceived.listen((String link) {
      debugPrint('✅ ChottuLink received: $link');
      onLink(link);
    });
  }

  // ── Deep-link parsing ────────────────────────────────────────────────

  /// Turns a deep-link URL into a GoRouter path.
  ///
  /// Supported schemes:
  ///   /news?id=<id>         → /news/<id>
  ///   /player?id=<id>       → /players/<id>
  ///   /match?id=<id>        → /matches/<id>
  ///   /fantasy?slug=<slug>  → /fantasy/<slug>
  ///   /league?id=<id>&slug=<slug> → /fantasy/<slug>/leagues
  ///   /card?id=<id>         → /cards/<id>
  ///
  /// Returns `null` if the URL can't be parsed → caller should just
  /// navigate to home.
  String? parseDeepLink(String rawUrl) {
    try {
      final uri = Uri.parse(rawUrl);
      final path = uri.path;
      final q = uri.queryParameters;

      switch (path) {
        case '/news':
          final id = q['id'];
          if (id != null) return '/news/$id';
          return '/news';
        case '/player':
          final id = q['id'];
          if (id != null) return '/players/$id';
          return '/home';
        case '/match':
          final id = q['id'];
          if (id != null) return '/matches/$id';
          return '/home';
        case '/fantasy':
          final slug = q['slug'];
          if (slug != null) return '/fantasy/$slug';
          return '/fantasy';
        case '/league':
          final slug = q['slug'] ?? 'global-cup-2026';
          return '/fantasy/$slug/leagues';
        case '/card':
          final id = q['id'];
          if (id != null) return '/cards/$id';
          return '/market';
        default:
          return null;
      }
    } catch (e) {
      debugPrint('❌ Error parsing deep link: $e');
      return null;
    }
  }

  // ── Share helpers ────────────────────────────────────────────────────

  /// Share a news article.
  Future<void> shareNews({
    required String articleId,
    required String title,
    String? imageUrl,
    String? source,
  }) async {
    _createAndShare(
      deepLink: '$_baseUrl/news?id=$articleId',
      utmCampaign: 'news_share',
      linkName: 'news_$articleId',
      socialTitle: title,
      socialDescription: source != null ? 'via $source on FootballMojo' : 'Read on FootballMojo',
      socialImageUrl: imageUrl,
      shareText: '$title\n\n',
    );
  }

  /// Share a player card.
  Future<void> sharePlayer({
    required String playerId,
    required String playerName,
    String? photoUrl,
    String? teamName,
  }) async {
    _createAndShare(
      deepLink: '$_baseUrl/player?id=$playerId',
      utmCampaign: 'player_share',
      linkName: 'player_$playerId',
      socialTitle: '$playerName — FootballMojo',
      socialDescription: teamName != null
          ? 'Check out $playerName ($teamName) on FootballMojo!'
          : 'Check out $playerName on FootballMojo!',
      socialImageUrl: photoUrl,
      shareText: 'Check out $playerName on FootballMojo!\n\n',
    );
  }

  /// Share a match.
  Future<void> shareMatch({
    required String matchId,
    required String homeTeam,
    required String awayTeam,
    int? homeScore,
    int? awayScore,
  }) async {
    final hasScore = homeScore != null && awayScore != null;
    final scoreLine = hasScore ? '$homeTeam $homeScore - $awayScore $awayTeam' : '$homeTeam vs $awayTeam';
    _createAndShare(
      deepLink: '$_baseUrl/match?id=$matchId',
      utmCampaign: 'match_share',
      linkName: 'match_$matchId',
      socialTitle: scoreLine,
      socialDescription: 'Follow live on FootballMojo',
      shareText: '$scoreLine\n\n',
    );
  }

  /// Share a fantasy league invite.
  Future<void> shareLeague({
    required String leagueId,
    required String leagueName,
    required String slug,
  }) async {
    _createAndShare(
      deepLink: '$_baseUrl/league?id=$leagueId&slug=$slug',
      utmCampaign: 'league_invite',
      linkName: 'league_$leagueId',
      socialTitle: 'Join "$leagueName" on FootballMojo!',
      socialDescription: 'Compete in the Global Cup fantasy league with me.',
      shareText: 'Join my fantasy league "$leagueName" on FootballMojo!\n\n',
    );
  }

  /// Share the user's WC2026 bracket. Optionally attaches a pre-rendered
  /// PNG (see `ShareService.renderArtifactToFile`).
  Future<void> shareBracket({
    String? championName,
    String? championCrestUrl,
    int? pointsAwarded,
    String? imagePath,
  }) async {
    final hasChampion = championName != null && championName.isNotEmpty;
    final title = hasChampion
        ? 'My WC 2026 bracket — $championName for the cup'
        : 'My WC 2026 bracket on FootballMojo';
    final description = pointsAwarded != null && pointsAwarded > 0
        ? '$pointsAwarded pts so far. Build yours and beat me.'
        : 'Build yours and see if you can beat me.';
    final shareText = hasChampion
        ? "I've got $championName lifting the cup 🏆 Make your bracket:\n\n"
        : "My WC 2026 bracket is in. Make yours:\n\n";
    _createAndShare(
      deepLink: '$_baseUrl/bracket',
      utmCampaign: 'bracket_share',
      linkName: 'bracket_share',
      socialTitle: title,
      socialDescription: description,
      socialImageUrl: championCrestUrl,
      shareText: shareText,
      imagePath: imagePath,
    );
  }

  /// Share the user's fantasy lineup for a specific gameweek.
  Future<void> shareFantasyLineup({
    required String slug,
    String? tournamentName,
    String? gameweekName,
    double? totalPoints,
    String? imagePath,
  }) async {
    final pts = totalPoints != null ? totalPoints.toStringAsFixed(1) : null;
    final title = pts != null
        ? '$pts pts — ${gameweekName ?? "my lineup"} on FootballMojo'
        : 'My ${tournamentName ?? "fantasy"} lineup on FootballMojo';
    _createAndShare(
      deepLink: '$_baseUrl/fantasy?slug=$slug',
      utmCampaign: 'fantasy_share',
      linkName: 'fantasy_${slug}_lineup',
      socialTitle: title,
      socialDescription: 'Pick your XI and compete in the Global Cup.',
      shareText: pts != null
          ? 'My PITCH lineup — $pts pts. Pick yours:\n\n'
          : 'My PITCH lineup is set. Pick yours:\n\n',
      imagePath: imagePath,
    );
  }

  /// Share the app itself.
  Future<void> shareApp() async {
    _createAndShare(
      deepLink: '$_baseUrl/',
      utmCampaign: 'app_share',
      linkName: 'app_share',
      socialTitle: 'FootballMojo — Cards, Fantasy & Live Scores',
      socialDescription: 'Your all-in-one FIFA World Cup 2026 companion.',
      shareText: 'Check out FootballMojo — the ultimate World Cup companion!\n\n',
    );
  }

  // ── Internal ─────────────────────────────────────────────────────────

  void _createAndShare({
    required String deepLink,
    required String utmCampaign,
    required String linkName,
    required String socialTitle,
    required String socialDescription,
    String? socialImageUrl,
    required String shareText,
    String? imagePath,
  }) {
    final files = imagePath != null ? [XFile(imagePath)] : <XFile>[];
    final parameters = CLDynamicLinkParameters(
      link: Uri.parse(deepLink),
      domain: _domain,
      androidBehaviour: CLDynamicLinkBehaviour.app,
      iosBehaviour: CLDynamicLinkBehaviour.app,
      utmCampaign: utmCampaign,
      utmMedium: 'app',
      utmSource: 'footballmojo_app',
      linkName: linkName,
      socialTitle: socialTitle,
      socialDescription: socialDescription,
      socialImageUrl: socialImageUrl,
    );

    ChottuLink.createDynamicLink(
      parameters: parameters,
      onSuccess: (link) {
        debugPrint('✅ ChottuLink created: $link');
        SharePlus.instance.share(
          ShareParams(text: '$shareText$link', files: files),
        );
      },
      onError: (error) {
        debugPrint('❌ ChottuLink error: ${error.description}');
        // Fallback: share PNG (if any) + text without a deep link.
        SharePlus.instance.share(
          ShareParams(text: shareText, files: files),
        );
      },
    );
  }
}
