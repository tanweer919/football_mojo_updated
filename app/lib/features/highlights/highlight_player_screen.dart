import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/design/app_colors.dart';
import '../../core/widgets/eyebrow.dart';
import 'youtube_embed.dart';

/// Navigation payload for the highlight player route (passed via GoRouter `extra`).
class HighlightArgs {
  const HighlightArgs({required this.url, required this.title});
  final String url;
  final String title;
}

/// In-app YouTube highlight player.
///
/// Uses `youtube_player_iframe` (the official IFrame Player API over the
/// `webview_flutter` plugin the app already ships — no new native module).
///
/// Rights-managed clips (FIFA highlights often are) can have *embedding
/// disabled by the owner*; YouTube then refuses to play them in ANY embed and
/// returns notEmbeddable/videoNotFound. There's no compliant way to play those
/// inline, so we detect the error and surface a "Watch on YouTube" button that
/// opens the clip in the YouTube app. Embeddable clips still play inline.
class HighlightPlayerScreen extends StatefulWidget {
  const HighlightPlayerScreen({super.key, required this.url, required this.title});
  final String url;
  final String title;

  @override
  State<HighlightPlayerScreen> createState() => _HighlightPlayerScreenState();
}

class _HighlightPlayerScreenState extends State<HighlightPlayerScreen> {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _sub;
  String? _videoId;
  bool _blocked = false; // can't play inline (embed disabled / unavailable / failed to start)
  bool _started = false; // player reached a real playback state at least once
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    // Highlights are a lean-back, full-bleed experience → force landscape +
    // immersive while this screen is up. Restored in dispose().
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final id = youtubeIdFrom(widget.url);
    _videoId = id;
    if (id != null) {
      final controller = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: false,
          enableCaption: false,
          // 6.x defaults origin to null; the IFrame player needs a valid origin
          // or it errors with "video unavailable" (153/152). Set it explicitly.
          origin: 'https://www.youtube.com',
        ),
      );
      _sub = controller.stream.listen((value) {
        // ANY player error means it can't play inline. Besides the documented
        // embed blocks (100/101/105/150), unmapped codes — notably the "152"
        // "video unavailable" screen — surface as YoutubeError.unknown, so we
        // treat every non-`none` error as blocked.
        if (value.error != YoutubeError.none) {
          if (!_blocked && mounted) setState(() => _blocked = true);
          return;
        }
        // Note the first time playback actually gets going, so the watchdog
        // below doesn't fire on a clip that simply loaded slowly.
        if (!_started) {
          switch (value.playerState) {
            case PlayerState.playing:
            case PlayerState.buffering:
            case PlayerState.cued:
            case PlayerState.paused:
            case PlayerState.ended:
              _started = true;
              _startTimer?.cancel();
            default:
              break;
          }
        }
      });
      // Some embed blocks (e.g. "152") render YouTube's own error page WITHOUT
      // firing onError, leaving the player silently stuck. If nothing has
      // started after a grace period, fall back to the "Watch on YouTube" card.
      _startTimer = Timer(const Duration(seconds: 8), () {
        if (!_started && !_blocked && mounted) setState(() => _blocked = true);
      });
      _controller = controller;
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _sub?.cancel();
    _controller?.close();
    // Restore the app's normal portrait lock + edge-to-edge chrome (mirrors
    // main.dart) — these are app-wide, so they must be reset on the way out.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _openOnYoutube() async {
    final id = _videoId;
    final uri = Uri.parse(id != null ? 'https://www.youtube.com/watch?v=$id' : widget.url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // No parseable id, or the owner blocked embedding → external-only fallback.
    if (controller == null || _blocked) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              _TopBar(
                title: widget.title,
                onBack: () => context.pop(),
                onOpenYoutube: controller == null && _videoId == null ? null : _openOnYoutube,
              ),
              Expanded(child: _Fallback(canOpen: _videoId != null, onOpen: _openOnYoutube)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(
              title: widget.title,
              onBack: () => context.pop(),
              onOpenYoutube: _openOnYoutube,
            ),
            // Centre + bound the 16:9 player so it letterboxes to fit the
            // landscape canvas instead of overflowing the column height.
            // We're already locked to landscape, so the player's own
            // auto-fullscreen is off to avoid fighting the orientation.
            Expanded(
              child: Center(
                child: YoutubePlayer(
                  controller: controller,
                  aspectRatio: 16 / 9,
                  autoFullScreen: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the clip can't be embedded — directs the user to YouTube.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.canOpen, required this.onOpen});
  final bool canOpen;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_display_outlined, size: 48, color: AppColors.muted),
            const SizedBox(height: 16),
            Text(
              canOpen ? 'Watch this highlight on YouTube' : 'This highlight is unavailable',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.fg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              canOpen
                  ? 'This clip can’t play inside the app, so it opens in YouTube.'
                  : 'We couldn’t find this video.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.muted, height: 1.4),
            ),
            if (canOpen) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: onOpen,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.live,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Watch on YouTube',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack, this.onOpenYoutube});
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onOpenYoutube;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.fg),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Eyebrow('HIGHLIGHTS', gold: true, size: 9),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.fg,
                  ),
                ),
              ],
            ),
          ),
          if (onOpenYoutube != null)
            IconButton(
              tooltip: 'Open in YouTube',
              onPressed: onOpenYoutube,
              icon: const Icon(Icons.open_in_new_rounded, color: AppColors.muted, size: 20),
            ),
        ],
      ),
    );
  }
}
