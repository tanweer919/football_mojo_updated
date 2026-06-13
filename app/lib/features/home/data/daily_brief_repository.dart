import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';

/// One AI-written daily digest (today's preview OR yesterday's recap).
class DailyDigest {
  DailyDigest({required this.content, required this.matchCount, this.generatedAt});
  factory DailyDigest.fromJson(Map<String, dynamic> j) => DailyDigest(
        content: (j['content'] as String? ?? '').trim(),
        matchCount: (j['matchCount'] as num?)?.toInt() ?? 0,
        generatedAt: j['generatedAt'] == null
            ? null
            : DateTime.tryParse(j['generatedAt'] as String),
      );
  final String content;
  final int matchCount;
  final DateTime? generatedAt;
  bool get hasContent => content.isNotEmpty;
}

/// Home "matchday brief": today's preview + yesterday's recap. Either may be
/// null on a rest day.
class DailyBrief {
  DailyBrief({this.preview, this.recap});
  factory DailyBrief.fromJson(Map<String, dynamic> j) {
    DailyDigest? parse(Object? v) =>
        v is Map<String, dynamic> ? DailyDigest.fromJson(v) : null;
    final p = parse(j['preview']);
    final r = parse(j['recap']);
    return DailyBrief(
      preview: (p?.hasContent ?? false) ? p : null,
      recap: (r?.hasContent ?? false) ? r : null,
    );
  }
  final DailyDigest? preview;
  final DailyDigest? recap;
  bool get isEmpty => preview == null && recap == null;
}

class DailyBriefRepository {
  DailyBriefRepository(this._dio);
  final Dio _dio;

  Future<DailyBrief> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/ai/daily');
    return DailyBrief.fromJson(res.data ?? const {});
  }
}

final dailyBriefRepositoryProvider =
    Provider<DailyBriefRepository>((ref) => DailyBriefRepository(ref.read(dioProvider)));

/// Cached per app session; the backend caches per date so it's cheap.
final dailyBriefProvider =
    FutureProvider<DailyBrief>((ref) => ref.read(dailyBriefRepositoryProvider).fetch());
