import { Suspense } from "react";

import { Logo } from "@/components/logo";
import { NavLinks, SidebarNav } from "@/components/sidebar";
import { getCurrentAdmin } from "@/lib/api";

import { logout } from "../login/actions";

/** Static shell renders instantly; only the admin badge waits on the session. */
export default function PanelLayout({ children }: LayoutProps<"/">) {
  return (
    <div className="mx-auto flex min-h-dvh max-w-[1400px] flex-col lg:flex-row">
      <aside className="border-b border-border px-4 py-4 lg:sticky lg:top-0 lg:h-dvh lg:w-64 lg:shrink-0 lg:border-r lg:border-b-0 lg:px-5 lg:py-6">
        <div className="mb-4 flex items-center justify-between lg:mb-8">
          <Logo />
        </div>
        <Suspense fallback={<NavLinks path="" />}>
          <SidebarNav />
        </Suspense>
        <div className="mt-4 lg:absolute lg:right-5 lg:bottom-6 lg:left-5">
          <Suspense fallback={<div className="h-14 animate-pulse rounded-xl bg-surface-2" />}>
            <AdminBadge />
          </Suspense>
        </div>
      </aside>
      <main id="main" className="min-w-0 flex-1 px-4 py-6 sm:px-6 lg:px-10 lg:py-10">
        {children}
      </main>
    </div>
  );
}

async function AdminBadge() {
  const admin = await getCurrentAdmin();
  return (
    <div className="flex items-center gap-3 rounded-xl border border-border bg-surface p-3">
      <span
        aria-hidden
        className="grid size-9 shrink-0 place-items-center rounded-full bg-accent text-sm font-bold text-on-accent"
      >
        {(admin.name || admin.email).slice(0, 1).toUpperCase()}
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-sm font-semibold">{admin.name || admin.email}</p>
        <p className="text-xs text-muted capitalize">{admin.role}</p>
      </div>
      <form action={logout}>
        <button type="submit" className="text-xs font-semibold text-muted hover:text-text">
          Sign out
        </button>
      </form>
    </div>
  );
}
