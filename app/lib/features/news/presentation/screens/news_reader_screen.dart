import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/deeplink/chottu_link_service.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/premium_image.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/models/news_article.dart';
import '../../data/repositories/news_repository.dart';

class NewsReaderScreen extends ConsumerStatefulWidget {
  const NewsReaderScreen({super.key, required this.articleId});
  final String articleId;
  @override
  ConsumerState<NewsReaderScreen> createState() => _NewsReaderScreenState();
}

class _NewsReaderScreenState extends ConsumerState<NewsReaderScreen> {
  static const _heroMaxHeight = 280.0;
  static const _heroMinHeight = 0.0;
  // Pixels of WebView scroll over which the hero collapses to compact.
  static const _scrollRange = 220.0;

  WebViewController? _controller;
  bool _loading = true;
  NewsArticleDto? _article;

  /// Current WebView scrollY, surfaced by JS injection. Drives the hero
  /// height interpolation so the hero slides away as the user scrolls.
  double _scrollY = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await ref.read(newsRepositoryProvider).byId(widget.articleId);
    _article = a;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg);
    // Channel that the injected JS uses to report scrollY back to us.
    // The web-view's own scroll surface is opaque to the Flutter scroll
    // gesture system, so JS injection is the only way to track it
    // without yanking the article into native rendering.
    controller.addJavaScriptChannel(
      'PitchScroll',
      onMessageReceived: (msg) {
        final y = double.tryParse(msg.message) ?? 0;
        if (mounted && (y - _scrollY).abs() > 1) {
          setState(() => _scrollY = y);
        }
      },
    );
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) async {
          await controller.runJavaScript(_scrollListenerJs);
          if (mounted) setState(() => _loading = false);
        },
      ),
    );
    await controller.loadRequest(Uri.parse(a.url));
    _controller = controller;
    setState(() {});
  }

  /// Posts scroll Y to the PitchScroll channel using rAF-throttled events
  /// so we don't spam the bridge. Falls back to document scroll for sites
  /// that wrap content in an inner scroller.
  static const _scrollListenerJs = '''
    (() => {
      let ticking = false;
      const report = () => {
        const y = window.scrollY || document.documentElement.scrollTop || 0;
        if (window.PitchScroll && window.PitchScroll.postMessage) {
          window.PitchScroll.postMessage(String(y));
        }
        ticking = false;
      };
      window.addEventListener('scroll', () => {
        if (!ticking) {
          window.requestAnimationFrame(report);
          ticking = true;
        }
      }, { passive: true });
      report();
    })();
  ''';

  @override
  Widget build(BuildContext context) {
    final article = _article;
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final progress = (_scrollY / _scrollRange).clamp(0.0, 1.0);
    final heroHeight = _heroMaxHeight +
        topInset -
        (_heroMaxHeight - _heroMinHeight) * progress;
    final compactHeight = topInset + kToolbarHeight;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: article == null
          ? const Center(child: Skeleton(height: 320, width: 280, radius: 20))
          : Column(
              children: [
                // Hero shrinks as the WebView scrolls. At max collapse it
                // becomes a thin AppBar-equivalent with back/share controls.
                _Hero(
                  article: article,
                  onBack: () => context.pop(),
                  onShare: _share,
                  height: heroHeight.clamp(compactHeight, _heroMaxHeight + topInset),
                  topInset: topInset,
                  progress: progress,
                ),
                if (_controller != null) ...[
                  if (_loading)
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: AppColors.gold,
                      backgroundColor: AppColors.surface,
                    ),
                  Expanded(child: WebViewWidget(controller: _controller!)),
                ],
              ],
            ),
    );
  }

  void _share() {
    final a = _article;
    if (a == null) return;
    ChottuLinkService.instance.shareNews(
      articleId: a.id,
      title: a.title,
      imageUrl: a.imageUrl,
      source: a.source,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.article,
    required this.onBack,
    required this.onShare,
    required this.height,
    required this.topInset,
    required this.progress,
  });
  final NewsArticleDto article;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final double height;
  final double topInset;
  /// 0 = fully expanded, 1 = fully collapsed.
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Title/source fade out as the hero collapses so the compact bar
    // only shows the controls + a subtle source line.
    final titleOpacity = (1.0 - progress * 1.8).clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Hero(
              tag: 'news-${article.id}',
              child: PremiumImage(url: article.imageUrl, fit: BoxFit.cover),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.5),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.85),
                  ],
                  stops: const [0.0, 0.4, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          // Solid bg behind the controls once the hero is mostly collapsed —
          // keeps the back/share buttons legible against any page header.
          if (progress > 0.85)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.bg
                      .withValues(alpha: (progress - 0.85) * 6.6),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleIconButton(icon: Icons.chevron_left, onPressed: onBack),
                    const Spacer(),
                    CircleIconButton(icon: Icons.bookmark_border, onPressed: () {}),
                    const SizedBox(width: 8),
                    CircleIconButton(icon: Icons.share_outlined, onPressed: onShare),
                  ],
                ),
                if (titleOpacity > 0.02) ...[
                  const Spacer(),
                  Opacity(
                    opacity: titleOpacity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(article.source, gold: true),
                        const SizedBox(height: 8),
                        Text(
                          article.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.44,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Eyebrow(
                          DateFormat('d MMM · h:mm a').format(article.publishedAt.toLocal()),
                          size: 9,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
