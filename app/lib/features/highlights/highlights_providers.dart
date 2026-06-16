import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../scores/data/models/match_dto.dart';
import '../scores/data/repositories/scores_repository.dart';

/// Finished matches that have a FIFA-official highlight, newest first.
final highlightsProvider = FutureProvider<List<MatchDto>>((ref) async {
  final repo = ref.read(scoresRepositoryProvider);
  final rows = await repo.fetchHighlights();
  return rows.where((m) => m.hasHighlight).toList(growable: false);
});
