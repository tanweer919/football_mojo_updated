/// Deterministic CDN URLs served by api-football's media bucket.
///
/// All endpoints accept the entity's numeric ID and return a square PNG with
/// transparent background. URLs are stable — safe to cache aggressively.
class ApiFootballMedia {
  ApiFootballMedia._();

  static const _base = 'https://media.api-sports.io/football';

  /// Player headshot — typically 100x100, transparent.
  /// Pass the api-football player id (NOT the internal database id).
  static String? player(Object? apiFootballId) {
    if (apiFootballId == null) return null;
    final id = _id(apiFootballId);
    if (id == null) return null;
    return '$_base/players/$id.png';
  }

  /// Team crest — typically 200x200, transparent.
  static String? team(Object? apiFootballId) {
    if (apiFootballId == null) return null;
    final id = _id(apiFootballId);
    if (id == null) return null;
    return '$_base/teams/$id.png';
  }

  /// League / competition logo.
  static String? league(Object? apiFootballId) {
    if (apiFootballId == null) return null;
    final id = _id(apiFootballId);
    if (id == null) return null;
    return '$_base/leagues/$id.png';
  }

  /// Country flag (3-letter ISO code lowercased).
  static String? country(String? code) {
    if (code == null || code.isEmpty) return null;
    return '$_base/flags/${code.toLowerCase()}.svg';
  }

  /// Returns the value if it parses as an integer, otherwise null.
  /// Backend payloads sometimes send the api-football id as a string.
  static String? _id(Object value) {
    if (value is int) return value.toString();
    if (value is String) return int.tryParse(value)?.toString();
    return null;
  }

  /// Resolve the most useful URL for a player, falling back through
  /// (1) an explicit URL, (2) api-football media URL, (3) null.
  static String? resolvePlayer({String? explicit, Object? apiFootballId}) {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return player(apiFootballId);
  }

  static String? resolveTeam({String? explicit, Object? apiFootballId}) {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    return team(apiFootballId);
  }
}
