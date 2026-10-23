import { Suspense } from "react";
import { PageTitle, Panel } from "@/components/shell";
import { Rows } from "@/components/rows";
import { credits, when } from "@/lib/format";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import type { SpinRecord, Transaction } from "@/lib/types";

export default function HistoryPage() {
  return (
    <Suspense fallback={<p className="text-muted">Loading history…</p>}>
      <History />
    </Suspense>
  );
}

async function History() {
  const auth = await requireUser(["PLAYER"]);
  const [transactions, spins] = await Promise.all([
    api<{ transactions: Transaction[] }>("/api/player/transactions", auth.token),
    api<{ spins: SpinRecord[] }>("/api/player/spins", auth.token),
  ]);
  return (
    <>
      <PageTitle kicker="Player" title="History" />
      <div className="grid gap-4">
        <Panel title="Plays">
          <Rows
            columns={["Game", "Bet", "Win", "Multiplier", "When"]}
            rows={spins.spins.map((spin) => [
              spin.gameName,
              credits(spin.betAmount),
              credits(spin.winAmount),
              `${spin.multiplier}x`,
              when(spin.createdAt),
            ])}
          />
        </Panel>
        <Panel title="Transactions">
          <Rows
            columns={["Type", "Amount", "Balance", "Note", "When"]}
            rows={transactions.transactions.map((row) => [
              row.transactionType,
              credits(row.amount),
              credits(row.balanceAfter),
              row.description,
              when(row.createdAt),
            ])}
          />
        </Panel>
      </div>
    </>
  );
}
