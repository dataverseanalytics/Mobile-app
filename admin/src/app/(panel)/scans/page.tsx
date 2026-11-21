import type { Metadata } from "next";
import Link from "next/link";

import { Badge, EmptyState, PageHeader, Pagination, TableShell, td, th } from "@/components/ui";
import { api } from "@/lib/api";
import { dateTime, num, pageParam, strParam } from "@/lib/format";
import { page as pageOf, ScanLogSchema } from "@/lib/schemas";

export const metadata: Metadata = { title: "AI usage" };

const FEATURE = { photo: "Photo scan", text: "Meal description", suggest: "Suggestions" } as const;

export default async function ScansPage({ searchParams }: PageProps<"/scans">) {
  const sp = await searchParams;
  const failedOnly = strParam(sp.failed) === "1";
  const kind = (["photo", "text", "suggest"] as const).find((k) => k === strParam(sp.kind)) ?? "all";
  const pageNo = pageParam(sp.page);
  const data = await api(
    `/v1/admin/scans?${new URLSearchParams({ failedOnly: String(failedOnly), kind, page: String(pageNo), size: "25" })}`,
    pageOf(ScanLogSchema),
  );
  const href = (p: number) =>
    `/scans?${new URLSearchParams({ ...(failedOnly ? { failed: "1" } : {}), ...(kind !== "all" ? { kind } : {}), page: String(p) })}`;

  return (
    <>
      <PageHeader title="AI usage" description="Every AI request — photo scans, meal descriptions and suggestions — with speed and outcome." />
      <div className="mb-3 flex flex-wrap gap-2" role="group" aria-label="Feature">
        {([
          ["all", "All features"],
          ["photo", "Photo scans"],
          ["text", "Meal descriptions"],
          ["suggest", "Suggestions"],
        ] as const).map(([k, label]) => (
          <Link
            key={k}
            href={k === "all" ? "/scans" : `/scans?kind=${k}`}
            aria-current={kind === k ? "page" : undefined}
            className={kind === k ? "btn-primary" : "btn-secondary"}
          >
            {label}
          </Link>
        ))}
      </div>
      <div className="mb-4 flex gap-2" role="group" aria-label="Filter">
        <Link href="/scans" aria-current={!failedOnly ? "page" : undefined} className={failedOnly ? "btn-secondary" : "btn-primary"}>
          All scans
        </Link>
        <Link href="/scans?failed=1" aria-current={failedOnly ? "page" : undefined} className={failedOnly ? "btn-primary" : "btn-secondary"}>
          Failed only
        </Link>
      </div>
      {data.items.length === 0 ? (
        <EmptyState
          title={failedOnly ? "No failed scans" : "No scans yet"}
          message={failedOnly ? "Every recent scan succeeded." : "Scans appear here when people photograph meals."}
        />
      ) : (
        <TableShell>
          <thead>
            <tr>
              <th className={th}>Result</th>
              <th className={th}>Feature</th>
              <th className={th}>Meal</th>
              <th className={`${th} text-right`}>kcal</th>
              <th className={`${th} text-right`}>Time</th>
              <th className={th}>Model</th>
              <th className={th}>When</th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((s) => (
              <tr key={s.id} className="hover:bg-surface-2/60">
                <td className={td}>
                  {s.success ? <Badge tone="success">Success</Badge> : <Badge tone="danger">Failed</Badge>}
                </td>
                <td className={`${td} text-muted`}>{FEATURE[s.kind]}</td>
                <td className={td}>
                  {s.success ? (
                    <span className="font-medium">{s.mealName}</span>
                  ) : (
                    <span className="text-muted">
                      {s.error === "no_food" ? "No food detected" : s.error === "not_food" ? "Not food" : s.error || "—"}
                    </span>
                  )}
                  {s.userId ? (
                    <Link href={`/users/${s.userId}`} className="block text-xs text-muted hover:underline">
                      View user
                    </Link>
                  ) : null}
                </td>
                <td className={`${td} tabular text-right`}>{s.success ? num(s.kcal) : "—"}</td>
                <td className={`${td} tabular text-right ${s.latencyMs > 5000 ? "text-warning" : ""}`}>
                  {(s.latencyMs / 1000).toFixed(1)} s
                </td>
                <td className={`${td} text-muted`}>{s.provider}</td>
                <td className={`${td} text-muted`}>{dateTime(s.createdAt)}</td>
              </tr>
            ))}
          </tbody>
        </TableShell>
      )}
      <Pagination page={data.page} size={data.size} total={data.total} href={href} />
    </>
  );
}
