import type { Metadata } from "next";
import Link from "next/link";

import { ConfirmAction } from "@/components/forms";
import { EmptyState, PageHeader, Pagination, SearchForm, TableShell, td, th } from "@/components/ui";
import { api } from "@/lib/api";
import { dateTime, num, pageParam, strParam } from "@/lib/format";
import { MealRowSchema, page as pageOf } from "@/lib/schemas";

import { deleteMeal } from "../actions";

export const metadata: Metadata = { title: "Meals" };

function healthTone(score: number) {
  if (score >= 8) return "text-success";
  if (score >= 6) return "text-warning";
  return "text-danger";
}

export default async function MealsPage({ searchParams }: PageProps<"/meals">) {
  const sp = await searchParams;
  const q = strParam(sp.q);
  const pageNo = pageParam(sp.page);
  const data = await api(
    `/v1/admin/meals?${new URLSearchParams({ q, page: String(pageNo), size: "25" })}`,
    pageOf(MealRowSchema),
  );

  return (
    <>
      <PageHeader title="Meals" description="Every meal logged in the app, newest first." />
      <SearchForm placeholder="Search meal name" defaultValue={q} />
      {data.items.length === 0 ? (
        <EmptyState
          title={q ? "No meals match" : "No meals yet"}
          message={q ? "Try a different name." : "Meals appear here as soon as people log them."}
        />
      ) : (
        <TableShell>
          <thead>
            <tr>
              <th className={th}>Meal</th>
              <th className={th}>User</th>
              <th className={`${th} text-right`}>kcal</th>
              <th className={`${th} text-right`}>P / C / F (g)</th>
              <th className={`${th} text-right`}>Health</th>
              <th className={th}>Logged</th>
              <th className={th}>
                <span className="sr-only">Actions</span>
              </th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((m) => (
              <tr key={`${m.userId}-${m.id}`} className="hover:bg-surface-2/60">
                <td className={td}>
                  <p className="font-semibold">{m.name}</p>
                  <p className="text-xs text-muted capitalize">{m.type}</p>
                </td>
                <td className={td}>
                  <Link href={`/users/${m.userId}`} className="hover:underline">
                    {m.userName || m.userPhone}
                  </Link>
                </td>
                <td className={`${td} tabular text-right font-semibold`}>{num(m.kcal)}</td>
                <td className={`${td} tabular text-right text-muted`}>
                  {num(m.protein)} / {num(m.carbs)} / {num(m.fat)}
                </td>
                <td className={`${td} tabular text-right font-semibold ${healthTone(m.healthScore)}`}>
                  {m.healthScore.toFixed(1)}
                </td>
                <td className={`${td} text-muted`}>{dateTime(m.loggedAt)}</td>
                <td className={`${td} text-right`}>
                  <ConfirmAction
                    action={deleteMeal}
                    hidden={{ userId: m.userId, mealId: m.id }}
                    label="Remove"
                    confirmLabel="Remove meal"
                    warning="Removes this meal from the user's diary."
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </TableShell>
      )}
      <Pagination
        page={data.page}
        size={data.size}
        total={data.total}
        href={(p) => `/meals?${new URLSearchParams({ q, page: String(p) })}`}
      />
    </>
  );
}
