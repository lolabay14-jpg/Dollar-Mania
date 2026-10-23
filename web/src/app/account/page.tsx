import { Suspense } from "react";
import { PasswordForm } from "@/components/forms";
import { Notice, PageTitle, Panel, Shell } from "@/components/shell";
import { requireUser } from "@/server/session";

export default function AccountPage({ searchParams }: { searchParams: Promise<{ updated?: string }> }) {
  return (
    <Suspense fallback={<p className="p-8 text-muted">Loading account…</p>}>
      <Account searchParams={searchParams} />
    </Suspense>
  );
}

async function Account({ searchParams }: { searchParams: Promise<{ updated?: string }> }) {
  const query = await searchParams;
  const auth = await requireUser();
  return (
    <Shell user={auth.user}>
      {query.updated ? <Notice>Password updated. Your session was refreshed.</Notice> : null}
      <PageTitle kicker="Account" title="Password" detail="Use at least 4 characters. The API issues a new session token." />
      <Panel>
        <PasswordForm />
      </Panel>
    </Shell>
  );
}
