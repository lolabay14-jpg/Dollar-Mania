import type { ReactNode } from "react";
import Link from "next/link";
import { logoutAction } from "@/server/actions";
import { linksFor } from "@/lib/nav";
import type { PublicUser } from "@/lib/types";

export function Shell({ user, children }: { user: PublicUser; children: ReactNode }) {
  const links = linksFor(user.role);
  return (
    <div className="min-h-screen">
      <header className="border-b border-line bg-panel/90">
        <div className="flex items-center justify-between gap-4 px-4 py-3">
          <div>
            <p className="font-display text-xl text-gold">Dollar Mania</p>
            <p className="text-xs tracking-wide text-muted uppercase">Virtual credits</p>
          </div>
          <div className="flex items-center gap-3 text-sm">
            <span className="text-muted">
              {user.username}
              <span className="ml-2 rounded-full border border-line px-2 py-0.5 text-xs text-gold-2">
                {user.role.replace("_", " ")}
              </span>
            </span>
            <form action={logoutAction}>
              <button className="btn-ghost" type="submit">
                Sign out
              </button>
            </form>
          </div>
        </div>
      </header>
      <div className="grid gap-4 px-3 py-3 md:grid-cols-[max-content_minmax(0,1fr)] md:px-4">
        <nav className="flex gap-1 overflow-x-auto md:flex-col">
          {links.map((link) => (
            <Link key={link.href} href={link.href} className="nav-link">
              {link.label}
            </Link>
          ))}
        </nav>
        <main className="min-w-0">{children}</main>
      </div>
    </div>
  );
}

export function PageTitle({
  kicker,
  title,
  detail,
}: {
  kicker?: string;
  title: string;
  detail?: string;
}) {
  return (
    <header className="mb-6">
      {kicker ? <p className="text-xs tracking-[0.16em] text-gold uppercase">{kicker}</p> : null}
      <h1 className="font-display text-3xl text-paper">{title}</h1>
      {detail ? <p className="mt-1 max-w-2xl text-muted">{detail}</p> : null}
    </header>
  );
}

export function Panel({
  title,
  action,
  children,
  className = "",
}: {
  title?: string;
  action?: ReactNode;
  children: ReactNode;
  className?: string;
}) {
  return (
    <section className={`rounded-2xl border border-line bg-panel p-4 ${className}`}>
      {title || action ? (
        <div className="mb-3 flex items-center justify-between gap-3">
          {title ? <h2 className="font-display text-xl">{title}</h2> : <span />}
          {action}
        </div>
      ) : null}
      {children}
    </section>
  );
}

export function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-line bg-panel px-4 py-3">
      <p className="text-xs tracking-wide text-muted uppercase">{label}</p>
      <p className="mt-1 font-display text-2xl text-gold-2">{value}</p>
    </div>
  );
}

export function Notice({ children }: { children: ReactNode }) {
  return <p className="mb-4 rounded-xl border border-gold/40 bg-gold/10 px-3 py-2 text-sm text-gold-2">{children}</p>;
}

export function ErrorText({ children }: { children: ReactNode }) {
  return <p className="rounded-xl border border-bad/40 bg-bad/10 px-3 py-2 text-sm text-bad">{children}</p>;
}

export function Badge({ children, tone = "neutral" }: { children: ReactNode; tone?: "neutral" | "good" | "bad" | "gold" }) {
  const tones = {
    neutral: "border-line text-muted",
    good: "border-good/40 text-good",
    bad: "border-bad/40 text-bad",
    gold: "border-gold/40 text-gold",
  };
  return <span className={`rounded-full border px-2 py-0.5 text-xs ${tones[tone]}`}>{children}</span>;
}

export function Empty({ children }: { children: ReactNode }) {
  return <p className="text-sm text-muted">{children}</p>;
}
