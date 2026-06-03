/** Single source of truth for site-wide constants (URLs, copy, contacts). */
export const SITE = {
  name: "FootballMojo",
  domain: "pitch.footballmojo.in",
  url: "https://pitch.footballmojo.in",
  tagline:
    "Live football, World Cup 2026 brackets, fantasy XI & collectible cards",
  description:
    "FootballMojo is the all-in-one football app for the FIFA World Cup 2026 — live scores, full tournament brackets, fantasy XI, score predictions, head-to-head leagues and collectible player cards. Free on Android.",
  androidAppId: "com.footballmojo",
  playStoreUrl:
    "https://play.google.com/store/apps/details?id=com.footballmojo",
  contactEmail: "support@footballmojo.in",
  privacyEmail: "support@footballmojo.in",
  // Keep in sync with the privacy policy footer.
  lastUpdated: "June 2026",
  keywords: [
    "football",
    "world cup",
    "world cup 2026",
    "FIFA World Cup 2026",
    "FootballMojo",
    "football mojo",
    "football app",
    "live football scores",
    "fantasy football",
    "fantasy XI",
    "world cup bracket",
    "world cup predictions",
    "football predictions",
    "soccer app",
    "football collectible cards",
    "head to head football leagues",
  ],
} as const;
