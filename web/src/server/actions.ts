"use server";

import { redirect, unstable_rethrow } from "next/navigation";
import { revalidatePath } from "next/cache";
import { api, ApiError } from "@/server/api";
import { clearSession, homeFor, requireUser, writeSession } from "@/server/session";
import type { PlayReceipt, PublicUser } from "@/lib/types";

export type ActionState = { error: string } | null;

function message(error: unknown) {
  if (error instanceof ApiError) {
    return error.message;
  }
  return "Something went wrong. Try again.";
}

function fail(error: unknown): ActionState {
  unstable_rethrow(error);
  return { error: message(error) };
}

export async function loginAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const username = String(formData.get("username") ?? "").trim();
  const password = String(formData.get("password") ?? "");
  if (!username || !password) {
    return { error: "Enter your username and password." };
  }

  try {
    const session = await api<{ token: string; user: PublicUser }>("/api/auth/login", null, {
      method: "POST",
      body: JSON.stringify({ username, password }),
    });
    await writeSession(session.token, session.user);
    redirect(homeFor(session.user.role));
  } catch (error) {
    return fail(error);
  }
}

export async function logoutAction() {
  await clearSession();
  redirect("/login");
}

export async function changePasswordAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const auth = await requireUser();
  const currentPassword = String(formData.get("currentPassword") ?? "");
  const newPassword = String(formData.get("newPassword") ?? "");
  const confirmPassword = String(formData.get("confirmPassword") ?? "");
  try {
    const result = await api<{ token: string }>("/api/auth/change-password", auth.token, {
      method: "POST",
      body: JSON.stringify({ currentPassword, newPassword, confirmPassword }),
    });
    await writeSession(result.token, auth.user);
  } catch (error) {
    return { error: message(error) };
  }
  redirect("/account?updated=1");
}

export async function requestCreditsAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const auth = await requireUser(["PLAYER"]);
  const amount = Number(formData.get("amount"));
  const note = String(formData.get("note") ?? "").trim();
  try {
    await api("/api/player/credit-requests", auth.token, {
      method: "POST",
      body: JSON.stringify({ amount, note: note || undefined }),
    });
  } catch (error) {
    return { error: message(error) };
  }
  revalidatePath("/player/requests");
  redirect("/player/requests?sent=1");
}

export async function spinAction(input: {
  slug: string;
  bet: number;
  choice: string | number | null;
}): Promise<{ ok: true; receipt: PlayReceipt } | { ok: false; error: string }> {
  const auth = await requireUser(["PLAYER"]);
  try {
    const receipt = await api<PlayReceipt>(`/api/games/${encodeURIComponent(input.slug)}/spin`, auth.token, {
      method: "POST",
      body: JSON.stringify({
        betAmount: input.bet,
        choice: input.choice ?? undefined,
        requestId: crypto.randomUUID(),
      }),
    });
    revalidatePath("/player");
    revalidatePath("/player/history");
    revalidatePath("/player/games");
    return { ok: true, receipt };
  } catch (error) {
    return { ok: false, error: message(error) };
  }
}

export async function createPlayerAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const body = {
    username: String(formData.get("username") ?? "").trim(),
    email: String(formData.get("email") ?? "").trim(),
    password: String(formData.get("password") ?? ""),
    confirmPassword: String(formData.get("confirmPassword") ?? ""),
    displayName: String(formData.get("displayName") ?? "").trim() || undefined,
    startingCredits: Number(formData.get("startingCredits")),
    role: "PLAYER" as const,
  };
  try {
    await api("/api/admin/users", auth.token, { method: "POST", body: JSON.stringify(body) });
  } catch (error) {
    return { error: message(error) };
  }
  revalidatePath("/admin/players");
  revalidatePath("/admin");
  redirect("/admin/players?created=1");
}

export async function updatePlayerAction(formData: FormData) {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const id = String(formData.get("id") ?? "");
  const displayName = String(formData.get("displayName") ?? "").trim();
  const isActive = String(formData.get("isActive") ?? "") === "true";
  await api(`/api/admin/users/${id}`, auth.token, {
    method: "PATCH",
    body: JSON.stringify({ displayName, isActive }),
  });
  revalidatePath(`/admin/players/${id}`);
  revalidatePath("/admin/players");
}

export async function setPlayerModeAction(formData: FormData) {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const id = String(formData.get("id") ?? "");
  const gameMode = String(formData.get("gameMode") ?? "");
  await api(`/api/admin/users/${id}/game-mode`, auth.token, {
    method: "PATCH",
    body: JSON.stringify({ gameMode }),
  });
  revalidatePath(`/admin/players/${id}`);
}

export async function adjustCreditsAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const id = String(formData.get("id") ?? "");
  const amount = Number(formData.get("amount"));
  const action = String(formData.get("action") ?? "");
  const note = String(formData.get("note") ?? "").trim();
  try {
    await api(`/api/admin/users/${id}/credits`, auth.token, {
      method: "POST",
      body: JSON.stringify({
        amount,
        action,
        note: note || undefined,
        requestId: crypto.randomUUID(),
      }),
    });
  } catch (error) {
    return { error: message(error) };
  }
  revalidatePath(`/admin/players/${id}`);
  revalidatePath("/admin");
  revalidatePath("/admin/activity");
  redirect(`/admin/players/${id}?credits=1`);
}

export async function saveGameProfileAction(formData: FormData) {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const id = String(formData.get("id") ?? "");
  const gameId = String(formData.get("gameId") ?? "");
  const profile = String(formData.get("profile") ?? "DEFAULT");
  const parameters: Record<string, number> = {};
  for (const [key, value] of formData.entries()) {
    if (key.startsWith("param:")) {
      parameters[key.slice(6)] = Number(value);
    }
  }
  await api(`/api/admin/users/${id}/game-profiles/${gameId}`, auth.token, {
    method: "PUT",
    body: JSON.stringify({ profile, parameters }),
  });
  revalidatePath(`/admin/players/${id}`);
}

export async function setPlatformModeAction(formData: FormData) {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const gameMode = String(formData.get("gameMode") ?? "");
  await api("/api/admin/settings/mode", auth.token, {
    method: "PUT",
    body: JSON.stringify({ gameMode }),
  });
  revalidatePath("/admin/games");
}

export async function setGameActiveAction(formData: FormData) {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const id = String(formData.get("id") ?? "");
  const isActive = String(formData.get("isActive") ?? "") === "true";
  await api(`/api/admin/games/${id}`, auth.token, {
    method: "PATCH",
    body: JSON.stringify({ isActive }),
  });
  revalidatePath("/admin/games");
  revalidatePath("/admin");
}

export async function reviewRequestAction(formData: FormData) {
  const auth = await requireUser(["ADMIN", "SUPER_ADMIN"]);
  const id = String(formData.get("id") ?? "");
  const action = String(formData.get("decision") ?? "");
  const note = String(formData.get("note") ?? "").trim();
  await api(`/api/admin/credit-requests/${id}/review`, auth.token, {
    method: "POST",
    body: JSON.stringify({ action, note: note || undefined }),
  });
  revalidatePath("/admin/requests");
  revalidatePath("/admin");
}

export async function staffRequestAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const auth = await requireUser(["ADMIN"]);
  const amount = Number(formData.get("amount"));
  const note = String(formData.get("note") ?? "").trim();
  try {
    await api("/api/admin/credit-requests", auth.token, {
      method: "POST",
      body: JSON.stringify({ amount, note: note || undefined }),
    });
  } catch (error) {
    return { error: message(error) };
  }
  revalidatePath("/admin/requests");
  redirect("/admin/requests?sent=1");
}

export async function createStaffAction(_state: ActionState, formData: FormData): Promise<ActionState> {
  const auth = await requireUser(["SUPER_ADMIN"]);
  const body = {
    username: String(formData.get("username") ?? "").trim(),
    email: String(formData.get("email") ?? "").trim(),
    password: String(formData.get("password") ?? ""),
    confirmPassword: String(formData.get("confirmPassword") ?? ""),
    displayName: String(formData.get("displayName") ?? "").trim() || undefined,
  };
  try {
    await api("/api/admin/staff", auth.token, { method: "POST", body: JSON.stringify(body) });
  } catch (error) {
    return { error: message(error) };
  }
  revalidatePath("/admin/staff");
  revalidatePath("/admin");
  redirect("/admin/staff?created=1");
}

export async function setStaffAccessAction(formData: FormData) {
  const auth = await requireUser(["SUPER_ADMIN"]);
  const id = String(formData.get("id") ?? "");
  const isActive = String(formData.get("isActive") ?? "") === "true";
  await api(`/api/admin/staff/${id}/access`, auth.token, {
    method: "PATCH",
    body: JSON.stringify({ isActive }),
  });
  revalidatePath("/admin/staff");
}

export async function setGameAccessAction(formData: FormData) {
  const auth = await requireUser(["SUPER_ADMIN"]);
  const playerId = String(formData.get("playerId") ?? "");
  const gameId = String(formData.get("gameId") ?? "");
  const enabled = String(formData.get("enabled") ?? "") === "true";
  const path = gameId
    ? `/api/admin/users/${playerId}/game-access/${gameId}`
    : `/api/admin/users/${playerId}/game-access`;
  await api(path, auth.token, {
    method: "PUT",
    body: JSON.stringify({ enabled }),
  });
  revalidatePath("/admin/access");
}
