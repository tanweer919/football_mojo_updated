import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/app_config.dart';

/// One Socket.IO connection per app process, multiplexed by all features.
/// Riverpod handles lifecycle: created lazily on first read, disposed on app teardown.
class SocketHub {
  SocketHub(String url) {
    _socket = io.io(
      url,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setPath('/realtime')
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10_000)
          .build(),
    );
    _socket.onConnect((_)    => debugPrint('socket: connected'));
    _socket.onDisconnect((_) => debugPrint('socket: disconnected'));
    _socket.connect();
  }

  late final io.Socket _socket;
  final Map<String, StreamController<Map<String, dynamic>>> _channels = {};

  /// Multi-subscriber stream for a given event name.
  Stream<Map<String, dynamic>> on(String event) {
    final ctrl = _channels.putIfAbsent(
      event,
      () {
        final c = StreamController<Map<String, dynamic>>.broadcast();
        _socket.on(event, (data) => c.add(_asMap(data)));
        return c;
      },
    );
    return ctrl.stream;
  }

  void emit(String event, [Object? data]) => _socket.emit(event, data);

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : Map<String, dynamic>.from(data as Map);

  Future<void> dispose() async {
    _socket.dispose();
    for (final c in _channels.values) {
      await c.close();
    }
    _channels.clear();
  }
}

final socketHubProvider = Provider<SocketHub>((ref) {
  final hub = SocketHub(ref.read(appConfigProvider).realtimeUrl);
  ref.onDispose(hub.dispose);
  return hub;
});
