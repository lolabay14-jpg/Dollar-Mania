import { Suspense } from "react";
import Link from "next/link";
import { Badge, Notice, PageTitle, Panel, Stat } from "@/components/shell";
import { Rows } from "@/components/rows";
import { credits, when } from "@/lib/format";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import type { PlayerProfile, SpinRecord, Transaction } from "@/lib/types";

export default function PlayerHomePage({ searchParams }: { searchParams: Promise<{ updated?: string }> }) {
  return (
    <Suspense fallback={<p className="text-muted">Loading overview…</p>}>
      <Home searchParams={searchParams} />
    </Suspense>
  );
}

async function Home({ searchParams }: { searchParams: Promise<{ updated?: string }> }) {
  const query = await searchParams;
  const auth = await requireUser(["PLAYER"]);
  const [profile, wallet, transactions, spins] = await Promise.all([
    api<{ profile: PlayerProfile }>("/api/player/profile", auth.token),
    api<{ balance: number }>("/api/player/wallet", auth.token),
    api<{ transactions: Transaction[] }>("/api/player/transactions", auth.token),
    api<{ spins: SpinRecord[] }>("/api/player/spins", auth.token),
  ]);
  const person = profile.profile;

  return (
    <>
      {query.updated ? <Notice>Password updated.</Notice> : null}
      <PageTitle
        kicker="Player"
        title={person.displayName || person.username}
        detail={`Level ${person.level} · ${person.spins} plays · ${person.wins} wins · ${person.losses} misses`}
      />
      <div className="mb-6 grid gap-3 sm:grid-cols-3">
        <Stat label="Credits" value={credits(wallet.balance)} />
        <Stat label="Plays" value={credits(person.spins)} />
        <Stat label="Experience" value={credits(person.experience)} />
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        <Panel title="Recent plays" action={<Link href="/player/history">All history</Link>}>
          <Rows
            columns={["Game", "Bet", "Win", "When"]}
            rows={spins.spins.slice(0, 6).map((spin) => [
              spin.gameName,
              credits(spin.betAmount),
              credits(spin.winAmount),
              when(spin.createdAt),
            ])}
          />
        </Panel>
        <Panel title="Wallet" action={<Link href="/player/requests">Request credits</Link>}>
          <Rows
            columns={["Type", "Amount", "Balance", "When"]}
            rows={transactions.transactions.slice(0, 6).map((row) => [
              <Badge key={row.id} tone={row.amount >= 0 ? "good" : "bad"}>
                {row.transactionType}
              </Badge>,
              credits(row.amount),
              credits(row.balanceAfter),
              when(row.createdAt),
            ])}
          />
        </Panel>
      </div>
      <p className="mt-6">
        <Link className="btn" href="/player/games">
          Open the game floor
        </Link>
      </p>
    </>
  );
}
