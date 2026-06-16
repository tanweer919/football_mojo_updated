import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

/// In-app YouTube highlight player. Plays the FIFA-official clip inside a
/// WebView (the app already depends on webview_flutter, so this needs no new
/// native plugin) by loading YouTube's inline embed. A thin top bar carries
/// the match title + back.
class HighlightPlayerScreen extends StatefulWidget {
  const HighlightPlayerScreen({super.key, required this.url, required this.title});
  final String url;
  final String title;

  @override
  State<HighlightPlayerScreen> createState() => _HighlightPlayerScreenState();
}

class _HighlightPlayerScreenState extends State<HighlightPlayerScreen> {
  WebViewController? _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final embed = youtubeEmbedUrl(widget.url);
    if (embed != null) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
        ))
        ..loadRequest(Uri.parse(embed));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(title: widget.title, onBack: () => context.pop()),
            if (_loading && _controller != null)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.gold,
                backgroundColor: Colors.black,
              ),
            Expanded(
              child: _controller == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'This highlight link looks invalid.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted, fontSize: 13),
                        ),
                      ),
                    )
                  : Center(
                      // 16:9 player centred on the black canvas.
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: WebViewWidget(controller: _controller!),
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
  const _TopBar({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
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
        ],
      ),
    );
  }
}
