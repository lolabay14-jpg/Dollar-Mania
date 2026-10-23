import { Suspense } from "react";
import Link from "next/link";
import { StaffCreditForm } from "@/components/forms";
import { Badge, Notice, PageTitle, Panel } from "@/components/shell";
import { credits, when } from "@/lib/format";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import { reviewRequestAction } from "@/server/actions";
import type { CreditRequest } from "@/lib/types";

const filters = ["PENDING", "APPROVED", "REJECTED", "ALL"] as const;

export default function RequestsAdminPage({ searchParams }: { searchParams: Promise<{ status?: string; sent?: string }> }) {
  return (
    <Suspense fallback={<p className="text-muted">Loading requests…</p>}>
      <Requests searchParams={searchParams} />
    </Suspense>
  );
}

async function Requests({ searchParams }: { searchParams: Promise<{ status?: string; sent?: string }> }) {
  const query = await searchParams;
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const status = filters.includes(query.status as (typeof filters)[number]) ? query.status : "PENDING";
  const data = await api<{ requests: CreditRequest[]; pendingCount: number; audience: string }>(
    `/api/admin/credit-requests?status=${status}`,
    auth.token,
  );
  const own =
    auth.user.role === "ADMIN"
      ? await api<{ requests: CreditRequest[] }>("/api/admin/credit-requests/own", auth.token)
      : { requests: [] };

  return (
    <>
      {query.sent ? <Notice>Request sent to the super admin.</Notice> : null}
      <PageTitle
        kicker="Treasury"
        title="Credit requests"
        detail={
          auth.user.role === "SUPER_ADMIN"
            ? `${data.pendingCount} admin requests waiting.`
            : `${data.pendingCount} player requests waiting.`
        }
      />
      <div className="mb-4 flex gap-2">
        {filters.map((filter) => (
          <Link key={filter} className={filter === status ? "btn" : "btn-ghost"} href={`/admin/requests?status=${filter}`}>
            {filter}
          </Link>
        ))}
      </div>
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_18rem]">
        <Panel title={`${data.audience} requests`}>
          <div className="grid gap-3">
            {data.requests.length === 0 ? <p className="text-sm text-muted">No requests in this view.</p> : null}
            {data.requests.map((request) => (
              <article key={request.id} className="rounded-xl border border-line p-3">
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <p>
                    {request.username} · {credits(request.amount)} credits
                    <span className="block text-xs text-muted">{request.email}</span>
                  </p>
                  <Badge tone={request.status === "APPROVED" ? "good" : request.status === "REJECTED" ? "bad" : "gold"}>
                    {request.status}
                  </Badge>
                </div>
                <p className="mt-1 text-sm text-muted">{request.requestNote || "No note"} · {when(request.createdAt)}</p>
                {request.status === "PENDING" ? (
                  <form action={reviewRequestAction} className="mt-3 flex flex-wrap items-center gap-2">
                    <input type="hidden" name="id" value={request.id} />
                    <input className="field max-w-xs" name="note" placeholder="Review note" maxLength={200} />
                    <button className="btn" name="decision" value="approve" type="submit">
                      Approve
                    </button>
                    <button className="btn-ghost" name="decision" value="reject" type="submit">
                      Reject
                    </button>
                  </form>
                ) : null}
              </article>
            ))}
          </div>
        </Panel>
        {auth.user.role === "ADMIN" ? (
          <div className="grid gap-4">
            <Panel title="Ask the treasury">
              <StaffCreditForm />
            </Panel>
            <Panel title="Your requests">
              {own.requests.map((request) => (
                <p key={request.id} className="mb-2 text-sm">
                  {credits(request.amount)} · {request.status}
                </p>
              ))}
              {own.requests.length === 0 ? <p className="text-sm text-muted">No treasury requests yet.</p> : null}
            </Panel>
          </div>
        ) : null}
      </div>
    </>
  );
}
