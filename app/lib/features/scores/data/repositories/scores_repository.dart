import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../datasources/scores_api_client.dart';
import '../datasources/scores_socket_client.dart';
import '../models/match_dto.dart';

final scoresRepositoryProvider = Provider<ScoresRepository>((ref) {
  return ScoresRepository(
    api: ref.read(scoresApiClientProvider),
    socket: ref.read(scoresSocketClientProvider),
  );
});

class ScoresRepository {
  ScoresRepository({required ScoresApiClient api, required ScoresSocketClient socket})
      : _api = api,
        _socket = socket;

  final ScoresApiClient _api;
  final ScoresSocketClient _socket;

  Future<List<MatchDto>> fetchLive() => _api.fetchLive();
  Future<List<MatchDto>> fetchFixtures({DateTime? day}) => _api.fetchFixtures(day: day);
  Future<MatchDto?> fetchMatch(String id) => _api.fetchMatch(id);

  Stream<MatchUpdate> updates() => _socket.updates();
  Stream<MatchUpdate> fixturesUpdates() => _socket.fixturesUpdates();
  void subscribeFixtures() => _socket.subscribeFixtures();
  void subscribeMatch(String id) => _socket.subscribeMatch(id);
  void unsubscribeMatch(String id) => _socket.unsubscribeMatch(id);
}
