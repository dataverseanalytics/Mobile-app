import type { Metadata } from "next";
import Link from "next/link";

import {
  Badge,
  EmptyState,
  PageHeader,
  Pagination,
  SearchForm,
  TableShell,
  td,
  th,
} from "@/components/ui";
import { api } from "@/lib/api";
import { num, pageParam, strParam } from "@/lib/format";
import { FoodRowSchema, page as pageOf } from "@/lib/schemas";

export const metadata: Metadata = { title: "Food database" };

export default async function FoodsPage({ searchParams }: PageProps<"/foods">) {
  const sp = await searchParams;
  const q = strParam(sp.q);
  const pageNo = pageParam(sp.page);
  const saved = strParam(sp.saved);
  const deleted = strParam(sp.deleted);
  const review = strParam(sp.review) === "1";
  const data = await api(
    `/v1/admin/foods?${new URLSearchParams({ q, review: String(review), page: String(pageNo), size: "25" })}`,
    pageOf(FoodRowSchema),
  );

  return (
    <>
      <PageHeader
        title="Food database"
        description="Foods people find when they search or scan a barcode in the app."
        action={
          <Link href="/foods/new" className="btn-primary">
            Add food
          </Link>
        }
      />
      {saved || deleted ? (
        <p role="status" className="mb-4 rounded-xl bg-success/10 px-4 py-3 text-sm text-success">
          {saved ? `“${saved}” saved — it's searchable in the app now.` : "Food deleted."}
        </p>
      ) : null}
      <div className="mb-4 flex flex-wrap gap-2" role="group" aria-label="Filter">
        <Link href="/foods" aria-current={!review ? "page" : undefined} className={review ? "btn-secondary" : "btn-primary"}>
          All foods
        </Link>
        <Link
          href="/foods?review=1"
          aria-current={review ? "page" : undefined}
          className={review ? "btn-primary" : "btn-secondary"}
        >
          AI estimates to review
        </Link>
      </div>
      {review ? (
        <p className="mb-4 text-sm text-muted">
          Added automatically when users described meals the database didn&apos;t know. Open one to check the numbers —
          saving it (or pressing Approve) marks it as reviewed.
        </p>
      ) : null}
      <SearchForm placeholder="Search foods" defaultValue={q}>
        {review ? <input type="hidden" name="review" value="1" /> : null}
      </SearchForm>
      {data.items.length === 0 ? (
        <EmptyState
          title={review ? "Nothing to review" : q ? "No foods match" : "Your food database is empty"}
          message={
            q
              ? "Check the spelling, or add it as a new food."
              : "Add common dishes so people can log them without a photo."
          }
          action={
            <Link href="/foods/new" className="btn-primary">
              Add food
            </Link>
          }
        />
      ) : (
        <TableShell>
          <thead>
            <tr>
              <th className={th}>Food</th>
              <th className={th}>Portion</th>
              <th className={`${th} text-right`}>kcal</th>
              <th className={`${th} text-right`}>Protein</th>
              <th className={`${th} text-right`}>Carbs</th>
              <th className={`${th} text-right`}>Fat</th>
              <th className={th}>Status</th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((f) => (
              <tr key={f.id} className="hover:bg-surface-2/60">
                <td className={td}>
                  <Link href={`/foods/${f.id}`} className="font-semibold hover:underline">
                    {f.name}
                  </Link>
                  {f.brand || f.barcode ? (
                    <p className="text-xs text-muted">
                      {[f.brand, f.barcode].filter(Boolean).join(" · ")}
                    </p>
                  ) : null}
                </td>
                <td className={`${td} text-muted`}>{f.unit}</td>
                <td className={`${td} tabular text-right font-semibold`}>{num(f.kcal)}</td>
                <td className={`${td} tabular text-right`}>{f.macros.p} g</td>
                <td className={`${td} tabular text-right`}>{f.macros.c} g</td>
                <td className={`${td} tabular text-right`}>{f.macros.f} g</td>
                <td className={td}>
                  <div className="flex flex-wrap gap-1.5">
                    {f.isActive ? <Badge tone="success">Live</Badge> : <Badge>Hidden</Badge>}
                    {f.source === "ai" && !f.reviewed ? <Badge tone="warning">AI estimate</Badge> : null}
                    {f.source === "ai" && f.reviewed ? <Badge>AI · checked</Badge> : null}
                  </div>
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
        href={(p) => `/foods?${new URLSearchParams({ q, page: String(p) })}`}
      />
    </>
  );
}
