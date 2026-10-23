import { Suspense } from "react";
import Link from "next/link";
import { notFound } from "next/navigation";
import { PlayPanel } from "@/components/play-panel";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import type { GameSummary } from "@/lib/types";

export default function PlayPage({ params }: { params: Promise<{ slug: string }> }) {
  return (
    <Suspense fallback={<p className="text-muted">Loading the table…</p>}>
      <Play params={params} />
    </Suspense>
  );
}

async function Play({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params;
  const auth = await requireUser(["PLAYER"]);
  const [{ games }, wallet] = await Promise.all([
    api<{ games: GameSummary[] }>("/api/player/games", auth.token),
    api<{ balance: number }>("/api/player/wallet", auth.token),
  ]);
  const game = games.find((item) => item.slug === slug);
  if (!game) {
    notFound();
  }
  return (
    <>
      <div className="mb-2 flex items-baseline justify-between gap-3">
        <h1 className="font-display truncate text-xl">{game.name}</h1>
        <Link className="shrink-0 text-xs text-muted" href="/player/games">
          Floor
        </Link>
      </div>
      {game.enabled === false ? (
        <p className="text-bad">
          This game is closed for your account. <Link href="/player/games">Back to the floor</Link>
        </p>
      ) : (
        <PlayPanel game={game} balance={wallet.balance} />
      )}
    </>
  );
}
