import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

/// A grounding citation behind an AI preview.
class AiSource {
  AiSource({required this.title, this.uri});
  factory AiSource.fromJson(Map<String, dynamic> j) {
    final uri = j['uri'] as String?;
    final title = (j['title'] as String?)?.trim();
    return AiSource(title: (title == null || title.isEmpty) ? (uri ?? 'Source') : title, uri: uri);
  }
  final String title;
  final String? uri;
}

/// On-demand, AI-written match preview (Gemini grounded with Google Search).
class AiMatchPreview {
  AiMatchPreview({
    required this.content,
    required this.sources,
    this.generatedAt,
    this.kind = 'preview',
  });
  factory AiMatchPreview.fromJson(Map<String, dynamic> j) => AiMatchPreview(
        content: (j['content'] as String? ?? '').trim(),
        sources: ((j['sources'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(AiSource.fromJson)
            .toList(growable: false),
        generatedAt: j['generatedAt'] == null
            ? null
            : DateTime.tryParse(j['generatedAt'] as String),
        kind: (j['kind'] as String?) ?? 'preview',
      );
  final String content;
  final List<AiSource> sources;
  final DateTime? generatedAt;

  /// 'preview' before kickoff, 'summary' once the match is live or finished.
  final String kind;
  bool get isSummary => kind == 'summary';
}

class AiPreviewRepository {
  AiPreviewRepository(this._dio);
  final Dio _dio;

  /// Generate (or fetch the cached) AI preview for a match. The backend
  /// caches per-match, so this is cheap after the first request.
  Future<AiMatchPreview> matchPreview(String matchId) async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/ai/matches/$matchId/preview');
    return AiMatchPreview.fromJson(res.data!);
  }
}

final aiPreviewRepositoryProvider =
    Provider<AiPreviewRepository>((ref) => AiPreviewRepository(ref.read(dioProvider)));
