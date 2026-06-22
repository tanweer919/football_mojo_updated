import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/design/app_colors.dart';
import '../../core/widgets/eyebrow.dart';
import 'youtube_embed.dart';

/// Navigation payload for the highlight player route (passed via GoRouter `extra`).
class HighlightArgs {
  const HighlightArgs({required this.url, required this.title});
  final String url;
  final String title;
}

// A clean mobile-Chrome user-agent. The default Android WebView UA contains
// "; wv)", which YouTube detects and refuses to serve its player to.
const _chromeUserAgent =
    'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

/// In-app highlight player.
///
/// Renders the SAME plain `<iframe>` embed that works on the web — not the
/// JS IFrame Player API the youtube_player_* packages use (that handshake was
/// failing with "video unavailable" 152/153). The combination that satisfies
/// YouTube's checks inside a WebView:
///   - a real document origin → `loadHtmlString(baseUrl: youtube.com)`
///     (Android's loadDataWithBaseURL), so the embed has a valid Referer,
///   - `referrerpolicy="strict-origin-when-cross-origin"` on the iframe,
///   - a clean (non-`wv`) user-agent.
/// An "Open in YouTube" action is always present as an escape hatch.
class HighlightPlayerScreen extends StatefulWidget {
  const HighlightPlayerScreen({super.key, required this.url, required this.title});
  final String url;
  final String title;

  @override
  State<HighlightPlayerScreen> createState() => _HighlightPlayerScreenState();
}

class _HighlightPlayerScreenState extends State<HighlightPlayerScreen> {
  WebViewController? _controller;
  String? _videoId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // Lean-back, full-bleed → landscape + immersive while open. Restored below.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final id = youtubeIdFrom(widget.url);
    _videoId = id;
    if (id != null) {
      final src =
          'https://www.youtube.com/embed/$id?playsinline=1&autoplay=1&rel=0&modestbranding=1';
      final html = '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  html, body { margin: 0; padding: 0; background: #000; height: 100%; overflow: hidden; }
  iframe { position: fixed; inset: 0; width: 100%; height: 100%; border: 0; }
</style>
</head>
<body>
  <iframe
    src="$src"
    referrerpolicy="strict-origin-when-cross-origin"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    allowfullscreen></iframe>
</body>
</html>
''';
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setUserAgent(_chromeUserAgent)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ))
        ..loadHtmlString(html, baseUrl: 'https://www.youtube.com');
    }
  }

  @override
  void dispose() {
    // Restore the app's portrait lock + edge-to-edge chrome (mirrors main.dart).
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
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(
              title: widget.title,
              onBack: () => context.pop(),
              onOpenYoutube: _videoId == null ? null : _openOnYoutube,
            ),
            if (_loading && controller != null)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.gold,
                backgroundColor: Colors.black,
              ),
            Expanded(
              child: Center(
                child: controller == null
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'This highlight link looks invalid.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      )
                    : AspectRatio(
                        aspectRatio: 16 / 9,
                        child: WebViewWidget(controller: controller),
                      ),
              ),
            ),
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
            TextButton.icon(
              onPressed: onOpenYoutube,
              icon: const Icon(Icons.open_in_new_rounded, color: AppColors.muted, size: 18),
              label: const Text(
                'YouTube',
                style: TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}
