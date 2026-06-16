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

/// Embed URL that autoplays inline inside a WebView. `youtube-nocookie` keeps
/// it privacy-friendly; `playsinline=1` avoids forcing the native fullscreen
/// player on iOS.
String? youtubeEmbedUrl(String? raw) {
  final id = youtubeIdFrom(raw);
  return id == null
      ? null
      : 'https://www.youtube-nocookie.com/embed/$id?autoplay=1&playsinline=1&rel=0&modestbranding=1';
}
