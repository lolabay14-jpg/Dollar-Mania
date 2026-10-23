import Link from "next/link";

export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-4">
      <p className="font-display text-3xl">Dollar Mania</p>
      <p className="mt-2 text-muted">The desk opens from the sign-in page.</p>
      <Link className="btn mt-6 w-fit" href="/login">
        Sign in
      </Link>
    </main>
  );
}
