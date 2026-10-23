import { Suspense } from "react";
import Link from "next/link";
import { CreateStaffForm } from "@/components/forms";
import { Badge, Notice, PageTitle, Panel } from "@/components/shell";
import { Rows } from "@/components/rows";
import { credits, when } from "@/lib/format";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import { setStaffAccessAction } from "@/server/actions";
import type { PlayerSummary } from "@/lib/types";

export default function StaffPage({ searchParams }: { searchParams: Promise<{ created?: string }> }) {
  return (
    <Suspense fallback={<p className="text-muted">Loading staff…</p>}>
      <Staff searchParams={searchParams} />
    </Suspense>
  );
}

async function Staff({ searchParams }: { searchParams: Promise<{ created?: string }> }) {
  const query = await searchParams;
  const auth = await requireUser(["SUPER_ADMIN"]);
  const { admins } = await api<{ admins: PlayerSummary[] }>("/api/admin/staff", auth.token);
  return (
    <>
      {query.created ? <Notice>Admin account created.</Notice> : null}
      <PageTitle kicker="Super admin" title="Staff" detail="Admins move player credits. They cannot create other admins." />
      <div className="grid gap-4 xl:grid-cols-[minmax(0,1fr)_20rem]">
        <Panel title="Admins">
          <Rows
            columns={["Admin", "Balance", "Status", "Access", "Joined"]}
            rows={admins.map((admin) => [
              <span key={admin.id}>
                {admin.displayName || admin.username}
                <Link className="block text-xs text-gold" href={`/admin/ledger/${admin.id}`}>
                  Ledger
                </Link>
              </span>,
              credits(admin.balance),
              <Badge key={`${admin.id}-badge`} tone={admin.isActive ? "good" : "bad"}>
                {admin.isActive ? "Active" : "Inactive"}
              </Badge>,
              <form key={`${admin.id}-access`} action={setStaffAccessAction}>
                <input type="hidden" name="id" value={admin.id} />
                <input type="hidden" name="isActive" value={String(!admin.isActive)} />
                <button className="btn-ghost" type="submit">
                  {admin.isActive ? "Disable" : "Enable"}
                </button>
              </form>,
              when(admin.createdAt),
            ])}
          />
        </Panel>
        <Panel title="New admin">
          <CreateStaffForm />
        </Panel>
      </div>
    </>
  );
}
