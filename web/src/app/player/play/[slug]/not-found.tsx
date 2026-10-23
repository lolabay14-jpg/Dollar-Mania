import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Game unavailable",
};

export default function NotFound() {
  return (
    <main className="px-4 py-10">
      <h1 className="font-display text-3xl">That game is not on the floor</h1>
      <p className="mt-2 text-muted">Check the catalog and pick a live game.</p>
    </main>
  );
}
