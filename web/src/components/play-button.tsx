import { SITE } from '@/lib/site';

/** The colourful Google Play triangle mark. */
function PlayMark({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 512 512" className={className} aria-hidden="true">
      <path fill="#00D2FF" d="M47 24C40 28 36 36 36 47v418c0 11 4 19 11 23l232-232L47 24z" />
      <path fill="#FFCE00" d="M357 184l-78-45-69 69 69 69 78-45c16-9 16-39 0-48z" />
      <path fill="#00F076" d="M47 24c5-3 12-3 19 1l213 114-69 69L47 24z" />
      <path fill="#FF3A44" d="M210 277L47 488c7 4 14 4 19 1l213-114-69-98z" />
    </svg>
  );
}

/**
 * Official-style "Get it on Google Play" button. Links to the live listing.
 * (Swap for the official Google Play badge asset if you prefer — drop it in
 * /public and replace the inner markup.)
 */
export function PlayButton({ className = '' }: { className?: string }) {
  return (
    <a
      href={SITE.playStoreUrl}
      target="_blank"
      rel="noopener"
      aria-label="Download FootballMojo on Google Play"
      className={
        'group inline-flex items-center gap-3 rounded-2xl border border-gold/40 bg-gradient-to-b from-surface-2 to-surface-1 px-5 py-3 transition hover:border-gold/70 hover:shadow-gold-glow ' +
        className
      }
    >
      <PlayMark className="h-7 w-7 shrink-0" />
      <span className="flex flex-col leading-none text-left">
        <span className="text-[10px] font-medium uppercase tracking-wide text-fg-muted">Get it on</span>
        <span className="mt-0.5 text-lg font-bold text-fg">Google Play</span>
      </span>
    </a>
  );
}
