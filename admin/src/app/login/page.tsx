import { LoginForm } from './form';

export default function LoginPage() {
  return (
    <main className="min-h-screen flex items-center justify-center px-6">
      <div className="w-full max-w-md">
        {/* Brand mark */}
        <div className="flex items-center gap-3 mb-10 justify-center">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-gold-soft via-gold to-gold-deep shadow-gold-glow" />
          <div>
            <div className="font-bold text-fg tracking-tight text-xl">PITCH</div>
            <div className="eyebrow-gold !text-[8px]">Admin Panel</div>
          </div>
        </div>

        <div className="panel-strong p-8 shadow-card">
          <h1 className="text-2xl font-extrabold tracking-tight mb-2">Sign in</h1>
          <p className="text-sm text-fg-muted mb-7 leading-relaxed">
            Only accounts promoted via <code className="font-mono text-gold bg-surface-2 px-1.5 py-0.5 rounded text-xs">admin:promote</code> can sign in here. If you should have access and don&apos;t, ask a SUPERADMIN.
          </p>
          <LoginForm />
        </div>

        <p className="text-center text-xs text-fg-muted2 mt-6">
          Internal tool · Not for public distribution
        </p>
      </div>
    </main>
  );
}
