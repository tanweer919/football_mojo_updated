import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'competition_models.dart';

class CompetitionsRepository {
  CompetitionsRepository(this._dio);
  final Dio _dio;

  Future<List<CompetitionDto>> list({bool onlyActive = true}) async {
    final res = await _dio.get<List<dynamic>>(
      '/v1/competitions',
      queryParameters: { 'active': onlyActive ? 'true' : 'false' },
    );
    return (res.data ?? const [])
        .cast<Map<String, dynamic>>()
        .map(CompetitionDto.fromJson)
        .toList(growable: false);
  }
}

final competitionsRepositoryProvider = Provider<CompetitionsRepository>((ref) {
  return CompetitionsRepository(ref.read(dioProvider));
});

/// All competitions known to the backend (active only). The app fetches this
/// at startup and every league/competition surface reads from it.
final competitionsProvider = FutureProvider<List<CompetitionDto>>((ref) {
  return ref.read(competitionsRepositoryProvider).list(onlyActive: true);
});

/// Every competition the backend knows, including past/future seasons. Powers
/// the Leagues screen's league + year (season) selector.
final allCompetitionsProvider = FutureProvider<List<CompetitionDto>>((ref) {
  return ref.read(competitionsRepositoryProvider).list(onlyActive: false);
});

/// The user's currently-selected competition for filtering Today / Matches.
/// `null` means "All" — show every match across every known competition.
class SelectedCompetitionNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}
final selectedCompetitionProvider =
    NotifierProvider<SelectedCompetitionNotifier, String?>(SelectedCompetitionNotifier.new);

/// The "primary" competition — what the Tournament tab opens to by default.
/// Backend pre-sorts: live first, then upcoming, then most-recent past.
final primaryCompetitionProvider = Provider<CompetitionDto?>((ref) {
  return ref.watch(competitionsProvider).maybeWhen(
    data: (list) => list.isEmpty ? null : list.first,
    orElse: () => null,
  );
});

/// The "default" fantasy tournament slug for the Fantasy bottom-nav tab.
/// Falls back to the WC slug if the backend hasn't been queried yet, so the
/// app still works on cold start.
const _kFallbackSlug = 'wc2026-global-cup';
final defaultFantasySlugProvider = Provider<String>((ref) {
  final primary = ref.watch(primaryCompetitionProvider);
  return primary?.primaryFantasy?.slug ?? _kFallbackSlug;
});
