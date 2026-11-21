"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";

const NAV = [
  { href: "/", label: "Dashboard", icon: "◧" },
  { href: "/users", label: "Users", icon: "◍" },
  { href: "/payments", label: "Payments", icon: "₹" },
  { href: "/meals", label: "Meals", icon: "◒" },
  { href: "/foods", label: "Food database", icon: "▤" },
  { href: "/broadcasts", label: "Notifications", icon: "◔" },
  { href: "/scans", label: "AI usage", icon: "◎" },
  { href: "/settings", label: "Settings", icon: "⚙" },
];

/** Reads the URL, so it renders inside <Suspense> (see the layout). */
export function SidebarNav() {
  return <NavLinks path={usePathname()} />;
}

/** Pure nav; with no path it's the instant fallback (no active item). */
export function NavLinks({ path }: { path: string }) {
  return (
    <nav aria-label="Main" className="flex gap-1 overflow-x-auto lg:flex-col lg:overflow-visible">
      {NAV.map((item) => {
        const active = item.href === "/" ? path === "/" : path.startsWith(item.href);
        return (
          <Link
            key={item.href}
            href={item.href}
            aria-current={active ? "page" : undefined}
            className={`flex min-h-11 shrink-0 items-center gap-3 rounded-xl px-3 text-sm font-medium transition-colors ${
              active ? "bg-ink text-on-ink" : "text-muted hover:bg-surface-2 hover:text-text"
            }`}
          >
            <span aria-hidden className="w-4 text-center">
              {item.icon}
            </span>
            {item.label}
          </Link>
        );
      })}
    </nav>
  );
}
