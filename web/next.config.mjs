/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  images: {
    // Team crests / flags come from api-football's media CDN.
    remotePatterns: [
      { protocol: 'https', hostname: 'media.api-sports.io' },
    ],
  },
};

export default nextConfig;
