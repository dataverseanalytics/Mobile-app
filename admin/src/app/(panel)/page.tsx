import type { Metadata } from "next";
import Link from "next/link";

import { BarChart } from "@/components/charts";
import { PageHeader, StatCard } from "@/components/ui";
import { api } from "@/lib/api";
import { moneyList, num, pct } from "@/lib/format";
import { StatsSchema } from "@/lib/schemas";

export const metadata: Metadata = { title: "Dashboard" };

export default async function DashboardPage() {
  const s = await api("/v1/admin/stats", StatsSchema);
  const conversion = s.totalUsers ? s.premiumUsers / s.totalUsers : 0;
  const maxCountry = Math.max(1, ...s.topCountries.map((c) => c.users));

  return (
    <>
      <PageHeader title="Dashboard" description="How NutriLens is doing right now." />
      {s.foodsToReview > 0 ? (
        <Link
          href="/foods?review=1"
          className="mb-4 flex items-center justify-between gap-4 rounded-2xl border border-border bg-surface px-5 py-4 text-sm hover:bg-surface-2"
        >
          <span>
            <span className="font-semibold">{s.foodsToReview} AI-estimated {s.foodsToReview === 1 ? "food" : "foods"}</span>{" "}
            <span className="text-muted">were added from users&apos; meal descriptions and need a quick check.</span>
          </span>
          <span className="font-semibold">Review →</span>
        </Link>
      ) : null}

      <section aria-label="Key numbers" className="grid grid-cols-2 gap-4 xl:grid-cols-4">
        <StatCard
          label="Total users"
          value={num(s.totalUsers)}
          hint={`+${num(s.newUsersWeek)} in the last 7 days`}
          highlight
        />
        <StatCard label="Active today" value={num(s.activeToday)} hint="Opened the app today" />
        <StatCard
          label="Pro subscribers"
          value={num(s.premiumUsers)}
          hint={`${pct(conversion)} conversion`}
        />
        <StatCard
          label="Revenue · 30 days"
          value={moneyList(s.revenueMonth.slice(0, 1))}
          hint={
            s.revenueMonth.length > 1
              ? `+ ${moneyList(s.revenueMonth.slice(1))} · ${num(s.paymentsMonth)} payments`
              : `${num(s.paymentsMonth)} payments · ${moneyList(s.revenueTotal)} all time`
          }
        />
      </section>

      <section aria-label="Trends" className="mt-6 grid gap-4 xl:grid-cols-2">
        <BarChart title="Sign-ups" points={s.signups} unit="users" />
        <BarChart title="Meals logged" points={s.meals} unit="meals" />
      </section>

      <section className="mt-6 grid gap-4 xl:grid-cols-3">
        <div className="xl:col-span-2">
          <BarChart title="AI scans" points={s.scans} unit="scans" />
        </div>
        <div className="card p-5">
          <h2 className="font-semibold">Scan quality</h2>
          <dl className="mt-4 space-y-4">
            <div>
              <dt className="text-sm text-muted">Success rate</dt>
              <dd className="tabular font-display text-2xl font-bold">{pct(s.scanSuccessRate)}</dd>
            </div>
            <div>
              <dt className="text-sm text-muted">Scans today</dt>
              <dd className="tabular font-display text-2xl font-bold">{num(s.scansToday)}</dd>
            </div>
            <div>
              <dt className="text-sm text-muted">Other AI requests today</dt>
              <dd className="tabular font-display text-2xl font-bold">{num(s.aiRequestsToday)}</dd>
            </div>
            <div>
              <dt className="text-sm text-muted">Average meal</dt>
              <dd className="tabular font-display text-2xl font-bold">
                {num(s.avgKcalPerMeal)} <span className="text-base font-medium text-muted">kcal</span>
              </dd>
            </div>
          </dl>
        </div>
      </section>

      <section className="card mt-6 p-5">
        <h2 className="font-semibold">Top countries</h2>
        {s.topCountries.length === 0 ? (
          <p className="mt-3 text-sm text-muted">Countries appear once people sign up.</p>
        ) : (
          <ul className="mt-4 space-y-3">
            {s.topCountries.map((c) => (
              <li key={c.country} className="grid grid-cols-[7rem_1fr_3rem] items-center gap-3 text-sm">
                <span>
                  {c.country}
                </span>
                <span className="h-2 overflow-hidden rounded-full bg-surface-2">
                  <span
                    className="block h-full rounded-full bg-text"
                    style={{ width: `${(c.users / maxCountry) * 100}%` }}
                  />
                </span>
                <span className="tabular text-right font-semibold">{c.users}</span>
              </li>
            ))}
          </ul>
        )}
      </section>
    </>
  );
}
