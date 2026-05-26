import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'PITCH Admin',
  description: 'Internal admin panel for FootballMojo / PITCH.',
  // Block search indexing — this is an internal tool.
  robots: { index: false, follow: false },
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="dark">
      <head>
        {/* Inline preconnect to Google Fonts so the Inter / JetBrains Mono
            stylesheet starts before the body parses. */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&family=JetBrains+Mono:wght@500;600;700&display=swap"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
