import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/dio_provider.dart';
import 'region.dart';

const _kWatchCountryKey = 'whereToWatch.country';

/// The viewer's "Where to watch" country, shared across the app (home hero +
/// match detail). Defaults to the device region but is **user-overridable +
/// persisted**, because the device locale is often wrong (an en-US phone used
/// in India reports US).
///
/// Detection order: persisted user pick → backend `/v1/geo/country` (IP-based,
/// no third-party limits) → public IP providers → device-locale placeholder.
class WatchCountryNotifier extends Notifier<String?> {
  bool _userPicked = false;

  @override
  String? build() {
    _init();
    return deviceCountryCode(); // instant placeholder while detection resolves
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kWatchCountryKey);
    if (saved != null && saved.isNotEmpty) {
      _userPicked = true;
      state = saved;
      return;
    }
    var code = await _countryFromBackend();
    code ??= await countryByIp();
    if (code != null && !_userPicked) state = code;
  }

  Future<String?> _countryFromBackend() async {
    try {
      final res = await ref.read(dioProvider).get<dynamic>('/v1/geo/country');
      final data = res.data;
      final code = (data is Map ? data['country'] : null)?.toString().trim();
      return (code != null && code.length == 2) ? code.toUpperCase() : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> set(String code) async {
    _userPicked = true;
    state = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWatchCountryKey, code);
  }
}

final watchCountryProvider =
    NotifierProvider<WatchCountryNotifier, String?>(WatchCountryNotifier.new);
