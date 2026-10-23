import type { Role } from "@/lib/types";

export type NavLink = {
  href: string;
  label: string;
};

export function linksFor(role: Role): NavLink[] {
  if (role === "PLAYER") {
    return [
      { href: "/player", label: "Overview" },
      { href: "/player/games", label: "Games" },
      { href: "/player/history", label: "History" },
      { href: "/player/requests", label: "Credits" },
      { href: "/account", label: "Password" },
    ];
  }

  const links: NavLink[] = [
    { href: "/admin", label: "Overview" },
    { href: "/admin/players", label: "Players" },
    { href: "/admin/games", label: "Games" },
    { href: "/admin/requests", label: "Requests" },
    { href: "/admin/activity", label: "Activity" },
  ];
  if (role === "SUPER_ADMIN") {
    links.push(
      { href: "/admin/staff", label: "Staff" },
      { href: "/admin/access", label: "Access" },
    );
  }
  links.push({ href: "/account", label: "Password" });
  return links;
}
