import Image from 'next/image';

/**
 * A device frame that wraps a portrait app screenshot. Screenshots live in
 * /public/screenshots and should be ~9:19.5 portrait (e.g. 1080×2340).
 */
export function PhoneFrame({
  src,
  alt,
  priority = false,
  className = '',
}: {
  src: string;
  alt: string;
  priority?: boolean;
  className?: string;
}) {
  return (
    <div className={`relative mx-auto w-full max-w-[270px] ${className}`}>
      <div className="relative rounded-[2.3rem] border border-white/12 bg-[#0b0a09] p-2 shadow-phone">
        {/* Notch */}
        <div className="absolute left-1/2 top-3 z-10 h-1.5 w-14 -translate-x-1/2 rounded-full bg-black/80" />
        <div className="relative aspect-[9/19.5] overflow-hidden rounded-[1.8rem] bg-gradient-to-b from-surface-2 to-surface-1">
          <Image
            src={src}
            alt={alt}
            fill
            priority={priority}
            sizes="270px"
            className="object-cover"
          />
        </div>
      </div>
    </div>
  );
}
