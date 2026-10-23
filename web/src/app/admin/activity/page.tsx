import { Suspense } from "react";
import { PageTitle, Panel } from "@/components/shell";
import { Rows } from "@/components/rows";
import { credits, when } from "@/lib/format";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import type { Activity, Transaction } from "@/lib/types";

export default function ActivityPage() {
  return (
    <Suspense fallback={<p className="text-muted">Loading activity…</p>}>
      <ActivityDesk />
    </Suspense>
  );
}

async function ActivityDesk() {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const [transactions, activity] = await Promise.all([
    api<{ transactions: Transaction[] }>("/api/admin/transactions", auth.token),
    api<{ activity: Activity[] }>("/api/admin/activity", auth.token),
  ]);
  return (
    <>
      <PageTitle kicker="Desk" title="Activity" />
      <div className="grid gap-4">
        <Panel title="Credit ledger">
          <Rows
            columns={["Who", "Type", "Amount", "Balance", "When"]}
            rows={transactions.transactions.map((row) => [
              row.username,
              row.transactionType,
              credits(row.amount),
              credits(row.balanceAfter),
              when(row.createdAt),
            ])}
          />
        </Panel>
        <Panel title="Staff actions">
          <Rows
            columns={["Action", "Staff", "Target", "Amount", "When"]}
            rows={activity.activity.map((row) => [
              row.action,
              row.adminUsername,
              row.targetDisplayName || row.targetUsername || "—",
              row.amount === null ? "—" : credits(row.amount),
              when(row.createdAt),
            ])}
          />
        </Panel>
      </div>
    </>
  );
}
