import type { Config } from 'tailwindcss';

/**
 * Admin theme — luxe dark + champagne gold, matching the Flutter app's
 * `AppColors` tokens. Kept narrow on purpose so the design has a strong
 * point of view rather than the generic "shadcn slate" look.
 */
const config: Config = {
  content: ['./src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: { DEFAULT: '#131211', deep: '#0A0A09' },
        surface: { 1: '#1A1815', 2: '#221F1A', 3: '#2A2620' },
        border: { DEFAULT: 'rgba(255,255,255,0.08)', soft: 'rgba(255,255,255,0.04)' },
        fg: { DEFAULT: '#F5EFE2', soft: '#C9C2B0', muted: '#8A8579', muted2: '#605C53' },
        gold: { DEFAULT: '#E5C26B', soft: '#EFD8A1', deep: '#C99A3D' },
        pitch: { DEFAULT: '#3EAD6A', glow: 'rgba(62,173,106,0.35)' },
        live: '#E5604D',
        info: '#4DBADC',
      },
      fontFamily: {
        sans: ['Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['JetBrains Mono', 'SF Mono', 'Menlo', 'monospace'],
      },
      boxShadow: {
        'gold-glow': '0 0 24px rgba(229,194,107,0.20)',
        'card': '0 8px 24px rgba(0,0,0,0.4)',
      },
      borderRadius: {
        'xs': '4px',
        'sm': '6px',
        'md': '10px',
        'lg': '14px',
        'xl': '18px',
      },
    },
  },
  plugins: [],
};

export default config;
