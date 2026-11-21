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
import { ago, date, pageParam, strParam } from "@/lib/format";
import { page as pageOf, UserRowSchema } from "@/lib/schemas";

export const metadata: Metadata = { title: "Users" };

const STATUSES = ["all", "premium", "free", "banned"] as const;

export default async function UsersPage({ searchParams }: PageProps<"/users">) {
  const sp = await searchParams;
  const q = strParam(sp.q);
  const statusRaw = strParam(sp.status);
  const status = STATUSES.find((s) => s === statusRaw) ?? "all";
  const pageNo = pageParam(sp.page);

  const qs = new URLSearchParams({ q, status, page: String(pageNo), size: "20" });
  const data = await api(`/v1/admin/users?${qs}`, pageOf(UserRowSchema));
  const href = (p: number) => `/users?${new URLSearchParams({ q, status, page: String(p) })}`;

  return (
    <>
      <PageHeader title="Users" description={`${data.total} ${data.total === 1 ? "person" : "people"}`} />
      {strParam(sp.deleted) ? (
        <p role="status" className="mb-4 rounded-xl bg-success/10 px-4 py-3 text-sm text-success">
          User and all their data deleted.
        </p>
      ) : null}

      <SearchForm placeholder="Search name, phone or email" defaultValue={q}>
        <label className="sr-only" htmlFor="status">
          Status
        </label>
        <select id="status" name="status" defaultValue={status} className="input w-auto">
          <option value="all">All users</option>
          <option value="premium">Pro</option>
          <option value="free">Free</option>
          <option value="banned">Suspended</option>
        </select>
      </SearchForm>

      {data.items.length === 0 ? (
        <EmptyState
          title={q || status !== "all" ? "No users match" : "No users yet"}
          message={
            q || status !== "all"
              ? "Try a different search or clear the filter."
              : "People appear here after they sign in to the app with their phone number."
          }
          action={
            q || status !== "all" ? (
              <Link className="btn-secondary" href="/users">
                Clear filters
              </Link>
            ) : undefined
          }
        />
      ) : (
        <TableShell>
          <thead>
            <tr>
              <th className={th}>User</th>
              <th className={th}>Country</th>
              <th className={th}>Plan</th>
              <th className={`${th} text-right`}>Meals</th>
              <th className={th}>Joined</th>
              <th className={th}>Last seen</th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((u) => (
              <tr key={u.id} className="hover:bg-surface-2/60">
                <td className={td}>
                  <Link href={`/users/${u.id}`} className="font-semibold hover:underline">
                    {u.name || "Unnamed"}
                  </Link>
                  <p className="tabular text-xs text-muted">{u.phone}</p>
                </td>
                <td className={td}>
                  {u.country || "—"}
                </td>
                <td className={td}>
                  <div className="flex gap-1.5">
                    {u.isPremium ? <Badge tone="accent">Pro</Badge> : <Badge>Free</Badge>}
                    {u.isBanned ? <Badge tone="danger">Suspended</Badge> : null}
                    {!u.onboarded ? <Badge tone="warning">Setup</Badge> : null}
                  </div>
                </td>
                <td className={`${td} tabular text-right`}>{u.mealCount}</td>
                <td className={td}>{date(u.createdAt)}</td>
                <td className={`${td} text-muted`}>{ago(u.lastSeenAt)}</td>
              </tr>
            ))}
          </tbody>
        </TableShell>
      )}
      <Pagination page={data.page} size={data.size} total={data.total} href={href} />
    </>
  );
}
