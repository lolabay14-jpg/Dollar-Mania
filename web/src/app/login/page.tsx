import { LoginForm } from "@/components/forms";

export default function LoginPage() {
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-4">
      <p className="text-xs tracking-[0.18em] text-gold uppercase">Dollar Mania</p>
      <h1 className="font-display mt-2 text-4xl">Sign in</h1>
      <p className="mt-2 mb-6 text-muted">
        Player, admin, and super-admin accounts use the same API as the Godot client. Credits stay virtual.
      </p>
      <LoginForm />
    </main>
  );
}
