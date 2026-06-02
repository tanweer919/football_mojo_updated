import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../core/deeplink/chottu_link_service.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/widgets/eyebrow.dart';
import '../../../../core/widgets/pitch_buttons.dart';
import '../../../../core/widgets/skeleton.dart';
import '../../data/models/news_article.dart';
import '../../data/repositories/news_repository.dart';

/// In-app reader for a news article.
///
/// Renders a compact top bar (back · source label · share) sitting
/// above the WebView. The previous design embedded a 280px hero that
/// collapsed on scroll via a JS scroll-position bridge; the bridge
/// turned out to make scrolling visibly judder on most articles, so
/// we replaced it with this simpler "thin app bar always pinned"
/// layout. Faster, smoother, less code.
class NewsReaderScreen extends ConsumerStatefulWidget {
  const NewsReaderScreen({super.key, required this.articleId});
  final String articleId;
  @override
  ConsumerState<NewsReaderScreen> createState() => _NewsReaderScreenState();
}

class _NewsReaderScreenState extends ConsumerState<NewsReaderScreen> {
  WebViewController? _controller;
  bool _loading = true;
  NewsArticleDto? _article;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await ref.read(newsRepositoryProvider).byId(widget.articleId);
    _article = a;
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.bg)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(a.url));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final article = _article;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: article == null
          ? const Center(child: Skeleton(height: 320, width: 280, radius: 20))
          : Column(
              children: [
                _TopBar(
                  source: article.source,
                  onBack: () => context.pop(),
                  onShare: _share,
                ),
                if (_loading)
                  const LinearProgressIndicator(
                    minHeight: 2,
                    color: AppColors.gold,
                    backgroundColor: AppColors.surface,
                  ),
                if (_controller != null)
                  Expanded(child: WebViewWidget(controller: _controller!)),
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

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.source,
    required this.onBack,
    required this.onShare,
  });
  final String source;
  final VoidCallback onBack;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Container(
      color: AppColors.bg,
      padding: EdgeInsets.fromLTRB(12, topInset + 8, 12, 10),
      child: Row(
        children: [
          CircleIconButton(icon: Icons.chevron_left, onPressed: onBack),
          const SizedBox(width: 8),
          Expanded(
            child: Eyebrow(source, gold: true, size: 11),
          ),
          const SizedBox(width: 8),
          CircleIconButton(icon: Icons.share_outlined, onPressed: onShare),
        ],
      ),
    );
  }
}
