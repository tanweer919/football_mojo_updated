import { forwardRef, type ButtonHTMLAttributes, type InputHTMLAttributes, type SelectHTMLAttributes, type TextareaHTMLAttributes, type HTMLAttributes, type ReactNode } from 'react';

/* ────────────────────────────────────────────────────────────────────────
   Minimal in-house UI kit. Kept in one file on purpose: every component is
   ~30 LOC and lives in the same visual language, so the cost of jumping
   between files outweighs the cost of one taller module.
   ──────────────────────────────────────────────────────────────────────── */

function cn(...xs: (string | false | undefined | null)[]) {
  return xs.filter(Boolean).join(' ');
}

// ─── Button ───────────────────────────────────────────────────────────────

type ButtonVariant = 'gold' | 'ghost' | 'danger' | 'soft';

interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: 'sm' | 'md';
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { variant = 'soft', size = 'md', className, children, ...rest },
  ref,
) {
  const base = 'inline-flex items-center justify-center gap-2 font-semibold rounded-md transition-colors disabled:opacity-50 disabled:cursor-not-allowed focus:outline-none focus-visible:ring-2 focus-visible:ring-gold/60';
  const sizes = { sm: 'h-8 px-3 text-xs', md: 'h-10 px-4 text-sm' }[size];
  const variants: Record<ButtonVariant, string> = {
    gold: 'bg-gradient-to-b from-gold-soft to-gold-deep text-[#1E1810] hover:brightness-105',
    soft: 'bg-surface-2 text-fg border border-border hover:bg-surface-3',
    ghost: 'text-fg-soft hover:text-fg hover:bg-surface-2',
    danger: 'bg-live/15 text-live border border-live/30 hover:bg-live/25',
  };
  return (
    <button ref={ref} className={cn(base, sizes, variants[variant], className)} {...rest}>
      {children}
    </button>
  );
});

// ─── Input / Textarea / Select ────────────────────────────────────────────

const fieldBase = 'w-full bg-surface-1 border border-border rounded-md px-3 py-2 text-sm text-fg placeholder:text-fg-muted2 focus:outline-none focus:border-gold/60 focus:ring-2 focus:ring-gold/15 transition-colors';

export const Input = forwardRef<HTMLInputElement, InputHTMLAttributes<HTMLInputElement>>(
  function Input({ className, ...rest }, ref) {
    return <input ref={ref} className={cn(fieldBase, className)} {...rest} />;
  },
);

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaHTMLAttributes<HTMLTextAreaElement>>(
  function Textarea({ className, ...rest }, ref) {
    return <textarea ref={ref} className={cn(fieldBase, 'min-h-[80px] resize-y', className)} {...rest} />;
  },
);

export const Select = forwardRef<HTMLSelectElement, SelectHTMLAttributes<HTMLSelectElement>>(
  function Select({ className, children, ...rest }, ref) {
    return (
      <select ref={ref} className={cn(fieldBase, 'appearance-none pr-8 cursor-pointer', className)} {...rest}>
        {children}
      </select>
    );
  },
);

// ─── Field (label + helper text + input) ─────────────────────────────────

export function Field({ label, hint, children, className }: {
  label: string;
  hint?: string;
  children: ReactNode;
  className?: string;
}) {
  return (
    <label className={cn('block', className)}>
      <span className="block eyebrow-gold mb-1.5">{label}</span>
      {children}
      {hint && <span className="block text-xs text-fg-muted2 mt-1.5">{hint}</span>}
    </label>
  );
}

// ─── Badge ───────────────────────────────────────────────────────────────

type BadgeTone = 'gold' | 'green' | 'red' | 'blue' | 'neutral';

export function Badge({ children, tone = 'neutral', className }: {
  children: ReactNode;
  tone?: BadgeTone;
  className?: string;
}) {
  const tones: Record<BadgeTone, string> = {
    gold: 'bg-gold/15 text-gold border-gold/30',
    green: 'bg-pitch/15 text-pitch border-pitch/30',
    red: 'bg-live/15 text-live border-live/30',
    blue: 'bg-info/15 text-info border-info/30',
    neutral: 'bg-surface-2 text-fg-soft border-border',
  };
  return (
    <span className={cn('inline-flex items-center px-2 py-0.5 rounded-full border text-[10px] font-bold tracking-wider uppercase font-mono', tones[tone], className)}>
      {children}
    </span>
  );
}

// ─── Panel / SectionHead ─────────────────────────────────────────────────

export function Panel({ children, className }: { children: ReactNode; className?: string }) {
  return <div className={cn('panel-strong p-5', className)}>{children}</div>;
}

export function SectionHead({ title, action, eyebrow }: { title: string; action?: ReactNode; eyebrow?: string }) {
  return (
    <div className="flex items-end justify-between mb-4">
      <div>
        {eyebrow && <div className="eyebrow-gold mb-1">{eyebrow}</div>}
        <h2 className="text-lg font-bold tracking-tight text-fg">{title}</h2>
      </div>
      {action}
    </div>
  );
}

// ─── Table primitives ────────────────────────────────────────────────────

export function Table({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className="panel-strong overflow-hidden">
      <table className={cn('w-full text-sm', className)}>{children}</table>
    </div>
  );
}

export function THead({ children }: { children: ReactNode }) {
  return (
    <thead className="bg-surface-2/40 border-b border-border">
      <tr>{children}</tr>
    </thead>
  );
}

export function TH({ children, className }: { children?: ReactNode; className?: string }) {
  return (
    <th className={cn('text-left px-4 py-2.5 eyebrow-gold !text-[9px] whitespace-nowrap', className)}>
      {children}
    </th>
  );
}

export function TR({ children, className, ...rest }: HTMLAttributes<HTMLTableRowElement>) {
  return (
    <tr className={cn('border-b border-border last:border-0 hover:bg-surface-2/40 transition-colors', className)} {...rest}>
      {children}
    </tr>
  );
}

export function TD({ children, className, ...rest }: HTMLAttributes<HTMLTableCellElement>) {
  return (
    <td className={cn('px-4 py-3 align-middle', className)} {...rest}>
      {children}
    </td>
  );
}

// ─── Empty state ────────────────────────────────────────────────────────

export function Empty({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="text-center py-16 px-6">
      <div className="text-3xl mb-3 opacity-40">∅</div>
      <div className="font-bold text-fg-soft">{title}</div>
      {hint && <div className="text-sm text-fg-muted mt-2 max-w-sm mx-auto">{hint}</div>}
    </div>
  );
}
