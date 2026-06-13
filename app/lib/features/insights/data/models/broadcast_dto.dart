/// "Where to watch" broadcast data for a fixture, grouped by country.
///
/// NOTE: api-football (the backend's current provider) does **not** expose
/// broadcaster/TV data — this is fed by a separate source server-side (e.g.
/// Sportmonks' TV-stations endpoint). The expected backend contract for
/// `GET /v1/insights/broadcasts/{fixtureId}` is a JSON array of:
/// ```
/// { "country": "IN", "countryName": "India",
///   "broadcasters": [ { "name": "JioStar", "logo": "https://…", "url": "https://…" } ] }
/// ```
class MatchBroadcastDto {
  MatchBroadcastDto({
    required this.countryCode,
    required this.countryName,
    required this.broadcasters,
  });

  factory MatchBroadcastDto.fromJson(Map<String, dynamic> j) {
    final raw = (j['broadcasters'] as List?) ?? const [];
    return MatchBroadcastDto(
      countryCode: ((j['country'] ?? j['countryCode']) as String? ?? '').toUpperCase(),
      countryName: (j['countryName'] ?? j['country_name'] ?? '') as String? ?? '',
      broadcasters: raw
          .cast<Map<String, dynamic>>()
          .map(BroadcasterDto.fromJson)
          .toList(growable: false),
    );
  }

  final String countryCode; // ISO-3166 alpha-2, e.g. "IN"
  final String countryName; // human-readable, e.g. "India"
  final List<BroadcasterDto> broadcasters;
}

class BroadcasterDto {
  BroadcasterDto({required this.name, this.logo, this.url});

  factory BroadcasterDto.fromJson(Map<String, dynamic> j) => BroadcasterDto(
        name: (j['name'] as String?) ?? '',
        logo: j['logo'] as String?,
        url: j['url'] as String?,
      );

  final String name;
  final String? logo;
  final String? url;
}
