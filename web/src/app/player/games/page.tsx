import { Suspense } from "react";
import Link from "next/link";
import { Badge, PageTitle } from "@/components/shell";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import type { GameSummary } from "@/lib/types";

export default function GamesPage() {
  return (
    <Suspense fallback={<p className="text-muted">Loading games…</p>}>
      <Games />
    </Suspense>
  );
}

async function Games() {
  const auth = await requireUser(["PLAYER"]);
  const { games } = await api<{ games: GameSummary[] }>("/api/player/games", auth.token);
  return (
    <>
      <PageTitle kicker="Floor" title="Games" detail="Every result is decided by the API. This page only plays it back." />
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {games.map((game) => {
          const open = game.enabled !== false;
          return (
            <article key={game.id} className="rounded-2xl border border-line bg-panel p-4">
              <div className="mb-2 flex items-center justify-between gap-2">
                <h2 className="font-display text-xl">{game.name}</h2>
                <Badge tone={open ? "gold" : "bad"}>{open ? game.difficulty : "Closed"}</Badge>
              </div>
              <p className="min-h-12 text-sm text-muted">{game.description}</p>
              <p className="mt-2 text-xs tracking-wide text-muted uppercase">
                {game.category} · {game.minimumBet}–{game.maximumBet}
              </p>
              {open ? (
                <Link className="btn mt-4" href={`/player/play/${game.slug}`}>
                  Play
                </Link>
              ) : (
                <p className="mt-4 text-sm text-bad">This game is turned off for your account.</p>
              )}
            </article>
          );
        })}
      </div>
    </>
  );
}
