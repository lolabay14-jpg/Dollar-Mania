import { Suspense } from "react";
import { CreditRequestForm } from "@/components/forms";
import { Badge, Notice, PageTitle, Panel } from "@/components/shell";
import { Rows } from "@/components/rows";
import { credits, when } from "@/lib/format";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import type { CreditRequest } from "@/lib/types";

export default function RequestsPage({ searchParams }: { searchParams: Promise<{ sent?: string }> }) {
  return (
    <Suspense fallback={<p className="text-muted">Loading requests…</p>}>
      <Requests searchParams={searchParams} />
    </Suspense>
  );
}

async function Requests({ searchParams }: { searchParams: Promise<{ sent?: string }> }) {
  const query = await searchParams;
  const auth = await requireUser(["PLAYER"]);
  const { requests } = await api<{ requests: CreditRequest[] }>("/api/player/credit-requests", auth.token);
  return (
    <>
      {query.sent ? <Notice>Credit request sent. An admin will review it.</Notice> : null}
      <PageTitle kicker="Wallet" title="Credit requests" detail="Ask an admin for more virtual credits. One request can be pending at a time." />
      <div className="grid gap-4 lg:grid-cols-[18rem_minmax(0,1fr)]">
        <Panel title="New request">
          <CreditRequestForm />
        </Panel>
        <Panel title="Your requests">
          <Rows
            columns={["Amount", "Status", "Note", "When"]}
            rows={requests.map((request) => [
              credits(request.amount),
              <Badge key={request.id} tone={request.status === "APPROVED" ? "good" : request.status === "REJECTED" ? "bad" : "gold"}>
                {request.status}
              </Badge>,
              request.requestNote || request.note || "—",
              when(request.createdAt),
            ])}
          />
        </Panel>
      </div>
    </>
  );
}
