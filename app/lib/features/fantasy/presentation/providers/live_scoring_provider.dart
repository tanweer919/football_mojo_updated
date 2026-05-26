import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'fantasy_providers.dart';

/// Periodic refresh of fantasy data while at least one match in the gameweek
/// is LIVE. Backend already runs a 60s scoring tick; this provider syncs the
/// client by invalidating myLineup + leaderboard every 30s.
///
/// Returns `true` when polling is active. UI can use this to render a "LIVE"
/// pulse badge.
///
/// Lifecycle: pauses while the app is backgrounded — there's no point burning
/// 30s ticks when the user can't see them. The first foreground tick after a
/// pause does an immediate refresh so coming back to the app shows fresh data.
final fantasyLivePollingProvider = StreamProvider.family.autoDispose<bool,
    ({String slug, String gameweekId})>((ref, args) {
  final controller = StreamController<bool>();
  Timer? timer;
  AppLifecycleListener? listener;
  var foregrounded = WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.hidden;

  Future<void> tick() async {
    if (!foregrounded) {
      // Skip the network — but still emit the cached `isLive` so subscribers
      // don't see a flicker into `false` while paused.
      return;
    }
    final gw = await ref.read(currentGameweekProvider(args.slug).future);
    final isLive = gw?.isLive ?? false;
    if (!controller.isClosed) controller.add(isLive);
    if (isLive) {
      ref.invalidate(myLineupProvider((slug: args.slug, gameweekId: args.gameweekId)));
      ref.invalidate(leaderboardProvider((slug: args.slug, gameweekId: args.gameweekId)));
    }
  }

  void start() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => tick());
  }

  // Initial fetch + start the ticker.
  tick();
  start();

  // Pause polling while backgrounded; refresh immediately on resume so the
  // user sees current data rather than stale lineup totals.
  listener = AppLifecycleListener(
    onResume: () {
      foregrounded = true;
      tick();      // immediate refresh
      start();     // restart timer with a fresh 30s window
    },
    onInactive: () {
      // Inactive (e.g. iOS app switcher) is still foreground-ish — keep going.
    },
    onPause: () {
      foregrounded = false;
      timer?.cancel();
    },
    onHide: () {
      foregrounded = false;
      timer?.cancel();
    },
  );

  ref.onDispose(() {
    timer?.cancel();
    listener?.dispose();
    controller.close();
  });
  return controller.stream;
});
