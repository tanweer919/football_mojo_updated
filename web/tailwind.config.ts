import type { Config } from 'tailwindcss';

/**
 * FootballMojo marketing theme — luxe dark + champagne gold + pitch green,
 * matching the app's `AppColors`. Tuned for a premium landing page.
 */
const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: { DEFAULT: '#0E0D0B', deep: '#080807', soft: '#16140F' },
        surface: { 1: '#1A1815', 2: '#221F1A', 3: '#2A2620' },
        border: { DEFAULT: 'rgba(255,255,255,0.09)', soft: 'rgba(255,255,255,0.05)' },
        fg: { DEFAULT: '#F7F2E6', soft: '#CBC4B2', muted: '#8C8779', muted2: '#615C53' },
        gold: { DEFAULT: '#E5C26B', soft: '#F2DDA6', deep: '#C99A3D', glow: 'rgba(229,194,107,0.28)' },
        pitch: { DEFAULT: '#3EAD6A', soft: '#5FCB87', glow: 'rgba(62,173,106,0.35)' },
        live: '#E5604D',
        info: '#4DBADC',
      },
      fontFamily: {
        sans: ['var(--font-inter)', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        display: ['var(--font-sora)', 'var(--font-inter)', 'ui-sans-serif', 'sans-serif'],
        mono: ['ui-monospace', 'SFMono-Regular', 'Menlo', 'monospace'],
      },
      boxShadow: {
        'gold-glow': '0 0 40px rgba(229,194,107,0.22)',
        card: '0 18px 50px -12px rgba(0,0,0,0.65)',
        phone: '0 40px 80px -20px rgba(0,0,0,0.75)',
      },
      borderRadius: { xs: '4px', sm: '8px', md: '12px', lg: '16px', xl: '22px', '2xl': '28px' },
      keyframes: {
        floaty: { '0%,100%': { transform: 'translateY(0)' }, '50%': { transform: 'translateY(-12px)' } },
        shimmer: { '0%': { backgroundPosition: '-200% 0' }, '100%': { backgroundPosition: '200% 0' } },
        fadeup: { '0%': { opacity: '0', transform: 'translateY(16px)' }, '100%': { opacity: '1', transform: 'translateY(0)' } },
      },
      animation: {
        floaty: 'floaty 6s ease-in-out infinite',
        shimmer: 'shimmer 6s linear infinite',
        fadeup: 'fadeup 0.7s cubic-bezier(0.22,1,0.36,1) both',
      },
    },
  },
  plugins: [],
};

export default config;
