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
  // Pixels of WebView scroll over which the hero collapses to compact.
  static const _scrollRange = 220.0;

  WebViewController? _controller;
  bool _loading = true;
  NewsArticleDto? _article;

  /// Drives the hero height animation without rebuilding the WebView.
  /// Previously we called setState on every scroll event, which rebuilt
  /// the full subtree (including WebViewWidget); during fast scrolls
  /// that thrashed the WebView and caused juddery/wacky scroll behaviour.
  /// A ValueNotifier scoped just to the hero animates without touching
  /// the WebView at all.
  final ValueNotifier<double> _scrollY = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollY.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final a = await ref.read(newsRepositoryProvider).byId(widget.articleId);
    _article = a;
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg);
    // JS channel — the injected listener reports scrollY back here.
    // We bridge straight into the ValueNotifier so neither setState nor
    // the WebView's parent ever rebuilds on scroll.
    controller.addJavaScriptChannel(
      'PitchScroll',
      onMessageReceived: (msg) {
        final y = double.tryParse(msg.message) ?? 0;
        if ((y - _scrollY.value).abs() > 1) _scrollY.value = y;
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

  /// Posts scroll Y to the PitchScroll channel using rAF-throttled events.
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
    final compactHeight = topInset + kToolbarHeight;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: article == null
          ? const Center(child: Skeleton(height: 320, width: 280, radius: 20))
          : Column(
              children: [
                // Hero shrinks as the WebView scrolls. AnimatedBuilder
                // scopes the rebuild to JUST the hero — the WebView
                // stays mounted and uninterrupted while the user scrolls,
                // so there's no jitter on the article content itself.
                ValueListenableBuilder<double>(
                  valueListenable: _scrollY,
                  builder: (context, y, _) {
                    final progress = (y / _scrollRange).clamp(0.0, 1.0);
                    final heroHeight = (_heroMaxHeight +
                            topInset -
                            (_heroMaxHeight - 0.0) * progress)
                        .clamp(compactHeight, _heroMaxHeight + topInset);
                    return _Hero(
                      article: article,
                      onBack: () => context.pop(),
                      onShare: _share,
                      height: heroHeight,
                      topInset: topInset,
                      progress: progress,
                    );
                  },
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
                          // Use local timezone — article timestamps come back
                          // as UTC and need to be presented in the reader's tz.
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
