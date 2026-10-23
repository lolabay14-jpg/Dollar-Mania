import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { api, ApiError } from "@/server/api";
import type { PublicUser, Role } from "@/lib/types";

const TOKEN = "dm_token";
const ROLE = "dm_role";
const USERNAME = "dm_username";
const USER_ID = "dm_user_id";
const MAX_AGE = 60 * 60 * 12;

const cookieOptions = {
  httpOnly: true,
  sameSite: "lax" as const,
  path: "/",
  maxAge: MAX_AGE,
  secure: process.env.NODE_ENV === "production",
};

export function homeFor(role: Role) {
  return role === "PLAYER" ? "/player" : "/admin";
}

export async function readSession() {
  const store = await cookies();
  const token = store.get(TOKEN)?.value;
  const role = store.get(ROLE)?.value as Role | undefined;
  const username = store.get(USERNAME)?.value;
  const id = store.get(USER_ID)?.value;
  if (!token || !role || !username || !id) {
    return null;
  }
  if (role !== "PLAYER" && role !== "ADMIN" && role !== "SUPER_ADMIN") {
    return null;
  }
  return { token, user: { id, username: decodeURIComponent(username), role } satisfies PublicUser };
}

export async function writeSession(token: string, user: PublicUser) {
  const store = await cookies();
  store.set(TOKEN, token, cookieOptions);
  store.set(ROLE, user.role, cookieOptions);
  store.set(USERNAME, encodeURIComponent(user.username), cookieOptions);
  store.set(USER_ID, user.id, cookieOptions);
}

export async function clearSession() {
  const store = await cookies();
  store.delete(TOKEN);
  store.delete(ROLE);
  store.delete(USERNAME);
  store.delete(USER_ID);
}

export async function requireUser(roles?: Role[]) {
  const session = await readSession();
  if (!session) {
    redirect("/login");
  }

  let me: { user: PublicUser };
  try {
    me = await api<{ user: PublicUser }>("/api/auth/me", session.token);
  } catch (error) {
    if (error instanceof ApiError && (error.status === 401 || error.status === 403)) {
      redirect("/session/end");
    }
    throw error;
  }

  if (roles && !roles.includes(me.user.role)) {
    redirect(homeFor(me.user.role));
  }

  return { token: session.token, user: me.user };
}
