import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/realtime/socket_provider.dart';
import '../models/match_dto.dart';

final scoresSocketClientProvider = Provider<ScoresSocketClient>((ref) {
  return ScoresSocketClient(ref.read(socketHubProvider));
});

class ScoresSocketClient {
  ScoresSocketClient(this._hub);
  final SocketHub _hub;

  Stream<MatchUpdate> updates() {
    return _hub
        .on('match.update')
        .map(MatchUpdate.fromJson)
        .asBroadcastStream();
  }

  Stream<MatchUpdate> fixturesUpdates() {
    return _hub
        .on('fixtures.update')
        .map(MatchUpdate.fromJson)
        .asBroadcastStream();
  }

  void subscribeFixtures()   => _hub.emit('subscribe.fixtures');
  void subscribeMatch(String id)   => _hub.emit('subscribe.match',   {'id': id});
  void unsubscribeMatch(String id) => _hub.emit('unsubscribe.match', {'id': id});
}
