import { Suspense } from "react";
import { PageTitle, Panel } from "@/components/shell";
import { Rows } from "@/components/rows";
import { credits, when } from "@/lib/format";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import type { PlayerSummary, Transaction } from "@/lib/types";

export default function LedgerPage({ params }: { params: Promise<{ id: string }> }) {
  return (
    <Suspense fallback={<p className="text-muted">Loading ledger…</p>}>
      <Ledger params={params} />
    </Suspense>
  );
}

async function Ledger({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const auth = await requireUser(["SUPER_ADMIN"]);
  const data = await api<{ user: PlayerSummary; transactions: Transaction[] }>(`/api/admin/users/${id}/ledger`, auth.token);
  return (
    <>
      <PageTitle
        kicker="Ledger"
        title={data.user.displayName || data.user.username}
        detail={`${data.user.role} · ${credits(data.user.balance)} credits`}
      />
      <Panel title="Transactions">
        <Rows
          columns={["Type", "Amount", "Balance", "Note", "When"]}
          rows={data.transactions.map((row) => [
            row.transactionType,
            credits(row.amount),
            credits(row.balanceAfter),
            row.description,
            when(row.createdAt),
          ])}
        />
      </Panel>
    </>
  );
}
