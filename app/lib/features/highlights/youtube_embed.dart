/// Parse a YouTube video id out of any of the common URL shapes admins might
/// paste (watch?v=, youtu.be/, shorts/, embed/, or a bare 11-char id), then
/// build a privacy-friendly embed URL for in-app playback.
String? youtubeIdFrom(String? raw) {
  final url = raw?.trim() ?? '';
  if (url.isEmpty) return null;
  if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(url)) return url;
  final patterns = <RegExp>[
    RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})'),
    RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
    RegExp(r'youtube\.com/(?:embed|shorts|v)/([a-zA-Z0-9_-]{11})'),
  ];
  for (final re in patterns) {
    final m = re.firstMatch(url);
    if (m != null) return m.group(1);
  }
  return null;
}

/// `mqdefault` thumbnail (320×180) for a video id — used in highlight cards.
String? youtubeThumb(String? raw) {
  final id = youtubeIdFrom(raw);
  return id == null ? null : 'https://i.ytimg.com/vi/$id/mqdefault.jpg';
}

/// Origin the embed is hosted under. Loading the player inside an HTML document
/// served from this base (rather than hitting the embed URL directly) gives
/// YouTube a valid referrer/origin — without it the IFrame player refuses to
/// start with "Error 153 · video player configuration error".
const youtubeEmbedOrigin = 'https://www.youtube.com';

/// Self-contained HTML page that fills the WebView with the YouTube IFrame
/// player for [raw]. Returns null if no video id can be parsed.
///
/// Must be loaded via `WebViewController.loadHtmlString(html, baseUrl:
/// youtubeEmbedOrigin)` so the iframe's `origin` matches its referrer.
String? youtubeIframeHtml(String? raw) {
  final id = youtubeIdFrom(raw);
  if (id == null) return null;
  final src =
      '$youtubeEmbedOrigin/embed/$id?autoplay=1&playsinline=1&rel=0&modestbranding=1&fs=1&origin=$youtubeEmbedOrigin';
  return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<style>
  html, body { margin: 0; padding: 0; background: #000; height: 100%; overflow: hidden; }
  .wrap { position: fixed; inset: 0; }
  iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: 0; }
</style>
</head>
<body>
  <div class="wrap">
    <iframe
      src="$src"
      allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
      allowfullscreen></iframe>
  </div>
</body>
</html>
''';
}
