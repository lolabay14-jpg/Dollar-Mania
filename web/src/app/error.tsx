"use client";

export default function Error({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <main className="mx-auto max-w-lg px-4 py-16">
      <h1 className="font-display text-3xl">The desk could not load</h1>
      <p className="mt-3 text-muted">{error.message}</p>
      <button className="btn mt-6" type="button" onClick={reset}>
        Try again
      </button>
    </main>
  );
}
