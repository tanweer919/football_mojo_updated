import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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
  bool _blocked = false; // owner disabled embedding (or video unavailable)

  @override
  void initState() {
    super.initState();
    final id = youtubeIdFrom(widget.url);
    _videoId = id;
    if (id != null) {
      final controller = YoutubePlayerController.fromVideoId(
        videoId: id,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          enableCaption: false,
        ),
      );
      _sub = controller.stream.listen((value) {
        final e = value.error;
        final blocked = e == YoutubeError.notEmbeddable ||
            e == YoutubeError.videoNotFound ||
            e == YoutubeError.cannotFindVideo;
        if (blocked && !_blocked && mounted) setState(() => _blocked = true);
      });
      _controller = controller;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _controller?.close();
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

    return YoutubePlayerScaffold(
      controller: controller,
      aspectRatio: 16 / 9,
      builder: (context, player) {
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
                player,
              ],
            ),
          ),
        );
      },
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
            const Text(
              'The broadcaster has disabled in-app playback for this clip.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: AppColors.muted, height: 1.4),
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
