/** @type {import('next').NextConfig} */
const nextConfig = {
  // Player and team images come from a handful of external CDNs we don't
  // control. Allow all https hosts — admins paste arbitrary URLs into the
  // photo editor, so we can't whitelist by hostname.
  images: {
    remotePatterns: [{ protocol: 'https', hostname: '**' }],
  },
  experimental: {
    // Server actions handle every mutation in the panel.
    serverActions: { bodySizeLimit: '2mb' },
  },
};

export default nextConfig;
