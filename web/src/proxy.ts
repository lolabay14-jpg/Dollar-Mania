import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import type { Role } from "@/lib/types";

function home(role: Role) {
  return role === "PLAYER" ? "/player" : "/admin";
}

export function proxy(request: NextRequest) {
  const token = request.cookies.get("dm_token")?.value;
  const role = request.cookies.get("dm_role")?.value as Role | undefined;
  const { pathname } = request.nextUrl;
  const signedIn = Boolean(token && role);

  if (pathname === "/") {
    return NextResponse.redirect(new URL(signedIn && role ? home(role) : "/login", request.url));
  }

  if (pathname === "/login" && signedIn && role) {
    return NextResponse.redirect(new URL(home(role), request.url));
  }

  const needsSession =
    pathname.startsWith("/player") || pathname.startsWith("/admin") || pathname.startsWith("/account");
  if (needsSession && !signedIn) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  if (!role) {
    return NextResponse.next();
  }

  if (pathname.startsWith("/player") && role !== "PLAYER") {
    return NextResponse.redirect(new URL(home(role), request.url));
  }

  if (pathname.startsWith("/admin") && role !== "ADMIN" && role !== "SUPER_ADMIN") {
    return NextResponse.redirect(new URL(home(role), request.url));
  }

  const superOnly = pathname.startsWith("/admin/staff") || pathname.startsWith("/admin/access") || pathname.startsWith("/admin/ledger");
  if (superOnly && role !== "SUPER_ADMIN") {
    return NextResponse.redirect(new URL("/admin", request.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ["/", "/login", "/player/:path*", "/admin/:path*", "/account/:path*"],
};
