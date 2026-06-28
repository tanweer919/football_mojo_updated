import Image from 'next/image';
import { flagEmoji } from '@/lib/api';

interface TeamLike {
  name: string;
  shortName?: string | null;
  crestUrl?: string | null;
  countryCode?: string | null;
}

/**
 * Reliable team flag/crest. Prefers the real crest image (works on every OS,
 * unlike flag emojis which Windows browsers don't render), then falls back to a
 * flag emoji, then to a 2–3 letter monogram. Fixed box → no layout shift.
 */
export function TeamCrest({ team, size = 22 }: { team: TeamLike; size?: number }) {
  const box = { width: size, height: size };
  if (team.crestUrl) {
    return (
      <span className="inline-flex shrink-0 items-center justify-center overflow-hidden rounded-sm" style={box}>
        <Image
          src={team.crestUrl}
          alt={`${team.name} crest`}
          width={size}
          height={size}
          className="h-full w-full object-contain"
          unoptimized
        />
      </span>
    );
  }
  const emoji = team.countryCode ? flagEmoji(team.countryCode) : '🌐';
  if (emoji !== '🌐') {
    return <span aria-hidden className="inline-block shrink-0 leading-none" style={{ fontSize: size * 0.8 }}>{emoji}</span>;
  }
  const mono = (team.shortName ?? team.name).slice(0, 3).toUpperCase();
  return (
    <span
      className="inline-flex shrink-0 items-center justify-center rounded-sm bg-surface-2 font-mono font-bold text-fg-muted"
      style={{ ...box, fontSize: size * 0.42 }}
      aria-hidden
    >
      {mono}
    </span>
  );
}
