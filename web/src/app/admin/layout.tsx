import { Suspense, type ReactNode } from "react";
import { Shell } from "@/components/shell";
import { requireUser } from "@/server/session";

export default function AdminLayout({ children }: { children: ReactNode }) {
  return (
    <Suspense fallback={<p className="p-8 text-muted">Loading the desk…</p>}>
      <Frame>{children}</Frame>
    </Suspense>
  );
}

async function Frame({ children }: { children: ReactNode }) {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  return <Shell user={auth.user}>{children}</Shell>;
}
