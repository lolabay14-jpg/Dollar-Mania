import { Suspense } from "react";
import Link from "next/link";
import { Badge, PageTitle } from "@/components/shell";
import { api } from "@/server/api";
import { requireUser } from "@/server/session";
import type { GameSummary } from "@/lib/types";

const categoryOrder = ["SLOTS", "SPIN", "SCRATCH", "REACTION", "CHOICE", "MATCH", "BONUS", "CARDS", "FISHING"];

function groups(games: GameSummary[]) {
  const buckets = new Map<string, GameSummary[]>();
  for (const game of games) {
    const list = buckets.get(game.category) ?? [];
    list.push(game);
    buckets.set(game.category, list);
  }
  const rank = (category: string) => {
    const index = categoryOrder.indexOf(category);
    return index === -1 ? categoryOrder.length : index;
  };
  return [...buckets.entries()].sort((left, right) => rank(left[0]) - rank(right[0]));
}

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
      <PageTitle kicker="Floor" title="Games" detail="Pick a table. The API decides the round, and the stage plays it back." />
      {groups(games).map(([category, items]) => (
        <section key={category} className="mb-8">
          <h2 className="mb-3 text-xs tracking-[0.16em] text-gold uppercase">{category}</h2>
          <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
            {items.map((game) => {
              const open = game.enabled !== false;
              return (
                <article key={game.id} className="game-card">
                  <div className="mb-2 flex items-center justify-between gap-2">
                    <h3 className="font-display text-xl">{game.name}</h3>
                    <Badge tone={open ? "gold" : "bad"}>{open ? game.difficulty : "Closed"}</Badge>
                  </div>
                  <p className="min-h-12 text-sm text-muted">{game.description}</p>
                  <p className="mt-2 text-xs tracking-wide text-muted uppercase">
                    {game.minimumBet}–{game.maximumBet} credits
                  </p>
                  {open ? (
                    <Link className="btn mt-4" href={`/player/play/${game.slug}`}>
                      Play
                    </Link>
                  ) : (
                    <p className="mt-4 text-sm text-bad">Closed for your account.</p>
                  )}
                </article>
              );
            })}
          </div>
        </section>
      ))}
    </>
  );
}
