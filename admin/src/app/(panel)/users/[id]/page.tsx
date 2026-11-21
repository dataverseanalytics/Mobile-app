import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { ActionForm, ConfirmAction, SubmitButton } from "@/components/forms";
import { Badge, StatCard } from "@/components/ui";
import { api, ApiError } from "@/lib/api";
import { ago, date, dateTime, num } from "@/lib/format";
import { UserDetailSchema } from "@/lib/schemas";

import { deleteUser, updateUser } from "../../actions";

export const metadata: Metadata = { title: "User" };

export default async function UserPage({ params }: PageProps<"/users/[id]">) {
  const { id } = await params;
  let d;
  try {
    d = await api(`/v1/admin/users/${encodeURIComponent(id)}`, UserDetailSchema);
  } catch (e) {
    if (e instanceof ApiError && (e.status === 404 || e.status === 422)) notFound();
    throw e;
  }
  const u = d.user;
  const kcal = (m: (typeof d.recentMeals)[number]) =>
    m.items.reduce((a, i) => a + (i.macros.p * 4 + i.macros.c * 4 + i.macros.f * 9) * i.servings, 0);

  return (
    <>
      <Link href="/users" className="text-sm font-medium text-muted hover:text-text">
        ← All users
      </Link>
      <header className="mt-3 mb-6 flex flex-wrap items-center gap-4">
        <span
          aria-hidden
          className="grid size-14 place-items-center rounded-full bg-accent font-display text-xl font-bold text-on-accent"
        >
          {(u.name || "?").slice(0, 1).toUpperCase()}
        </span>
        <div className="min-w-0 flex-1">
          <h1 className="font-display text-2xl font-bold tracking-tight">{u.name || "Unnamed user"}</h1>
          <p className="tabular text-sm text-muted">
            {u.phone}
            {u.email ? ` · ${u.email}` : ""}
          </p>
        </div>
        <div className="flex flex-wrap gap-1.5">
          {u.isPremium ? <Badge tone="accent">Pro</Badge> : <Badge>Free</Badge>}
          {d.isBanned ? <Badge tone="danger">Suspended</Badge> : null}
          {u.onboarded ? <Badge tone="success">Onboarded</Badge> : <Badge tone="warning">In setup</Badge>}
        </div>
      </header>

      <section className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard label="Meals logged" value={num(d.mealCount)} />
        <StatCard label="AI scans" value={num(d.scanCount)} />
        <StatCard label="Free scans left" value={u.isPremium ? "∞" : num(u.freeScansLeft)} />
        <StatCard label="Last seen" value={ago(d.lastSeenAt)} hint={`Joined ${date(u.createdAt)}`} />
      </section>

      <div className="mt-6 grid gap-6 xl:grid-cols-3">
        <section className="card p-5 xl:col-span-2">
          <h2 className="font-semibold">Recent meals</h2>
          {d.recentMeals.length === 0 ? (
            <p className="mt-3 text-sm text-muted">No meals logged yet.</p>
          ) : (
            <ul className="mt-3 divide-y divide-border">
              {d.recentMeals.map((m) => (
                <li key={m.id} className="flex items-center justify-between gap-4 py-3">
                  <div className="min-w-0">
                    <p className="truncate font-medium">{m.name}</p>
                    <p className="text-xs text-muted capitalize">
                      {m.type} · {dateTime(m.loggedAt)} · health {m.healthScore.toFixed(1)}
                    </p>
                  </div>
                  <span className="tabular shrink-0 font-semibold">{num(kcal(m))} kcal</span>
                </li>
              ))}
            </ul>
          )}
        </section>

        <section className="space-y-4" aria-label="Manage user">
          <div className="card p-5">
            <h2 className="font-semibold">Subscription</h2>
            <p className="mt-1 text-sm text-muted">
              {u.isPremium
                ? `Pro until ${u.premiumUntil ? date(u.premiumUntil) : "further notice"}.`
                : "On the free plan."}
            </p>
            <ActionForm action={updateUser} className="mt-4">
              <input type="hidden" name="id" value={u.id} />
              <input type="hidden" name="field" value="isPremium" />
              <input type="hidden" name="value" value={String(!u.isPremium)} />
              <SubmitButton variant="secondary" pendingLabel="Saving…">
                {u.isPremium ? "Remove Pro access" : "Grant Pro access"}
              </SubmitButton>
            </ActionForm>
          </div>

          <div className="card p-5">
            <h2 className="font-semibold">Free scans</h2>
            <ActionForm action={updateUser} className="mt-3">
              <input type="hidden" name="id" value={u.id} />
              <input type="hidden" name="field" value="freeScansLeft" />
              <label htmlFor="scans" className="mb-1.5 block text-sm text-muted">
                Scans remaining on the free plan
              </label>
              <div className="flex gap-2">
                <input
                  id="scans"
                  name="value"
                  type="number"
                  min={0}
                  max={1000}
                  defaultValue={u.freeScansLeft}
                  className="input w-28"
                />
                <SubmitButton variant="secondary" pendingLabel="Saving…">
                  Update
                </SubmitButton>
              </div>
            </ActionForm>
          </div>

          <div className="card p-5">
            <h2 className="font-semibold">Access</h2>
            <p className="mt-1 text-sm text-muted">
              {d.isBanned
                ? "Suspended users can't use the app or sign in."
                : "Suspending signs them out and blocks sign-in."}
            </p>
            <ActionForm action={updateUser} className="mt-4">
              <input type="hidden" name="id" value={u.id} />
              <input type="hidden" name="field" value="isBanned" />
              <input type="hidden" name="value" value={String(!d.isBanned)} />
              <SubmitButton variant={d.isBanned ? "secondary" : "danger"} pendingLabel="Saving…">
                {d.isBanned ? "Reinstate user" : "Suspend user"}
              </SubmitButton>
            </ActionForm>
            <div className="mt-4 border-t border-border pt-4">
              <ConfirmAction
                action={deleteUser}
                hidden={{ id: u.id }}
                label="Delete user…"
                confirmLabel="Delete user permanently"
                warning={`This deletes ${u.name || "this user"}'s account, ${d.mealCount} meals and all progress. It can't be undone. Owners only.`}
              />
            </div>
          </div>
        </section>
      </div>
    </>
  );
}
