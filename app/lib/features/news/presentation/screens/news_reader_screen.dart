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
        onPageFinished: (_) => setState(() => _loading = false),
      ))
      ..loadRequest(Uri.parse(a.url));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: _article == null
          ? const Center(child: Skeleton(height: 320, width: 280, radius: 20))
          : Column(
              children: [
                _Hero(article: _article!, onBack: () => context.pop(), onShare: () => _share()),
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
  const _Hero({required this.article, required this.onBack, required this.onShare});
  final NewsArticleDto article;
  final VoidCallback onBack;
  final VoidCallback onShare;
  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    return Stack(
      children: [
        Hero(
          tag: 'news-${article.id}',
          child: SizedBox(
            height: 280 + topInset,
            width: double.infinity,
            child: PremiumImage(url: article.imageUrl, fit: BoxFit.cover),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: 0.4),
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
              SizedBox(height: 280 + topInset - 220),
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
    );
  }
}
