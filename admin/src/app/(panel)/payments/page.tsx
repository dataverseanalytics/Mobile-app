import type { Metadata } from "next";
import Link from "next/link";

import { Badge, EmptyState, PageHeader, Pagination, TableShell, td, th } from "@/components/ui";
import { api } from "@/lib/api";
import { dateTime, money, pageParam, strParam } from "@/lib/format";
import { page as pageOf, PaymentRowSchema } from "@/lib/schemas";

export const metadata: Metadata = { title: "Payments" };

const FILTERS = [
  { id: "paid", label: "Paid" },
  { id: "created", label: "Started, not paid" },
  { id: "failed", label: "Failed" },
  { id: "all", label: "All" },
] as const;

const TONE = { paid: "success", created: "neutral", failed: "danger" } as const;
const STATUS_LABEL = { paid: "Paid", created: "Not completed", failed: "Failed" } as const;

export default async function PaymentsPage({ searchParams }: PageProps<"/payments">) {
  const sp = await searchParams;
  const status = FILTERS.find((f) => f.id === strParam(sp.status))?.id ?? "paid";
  const pageNo = pageParam(sp.page);
  const data = await api(
    `/v1/admin/payments?${new URLSearchParams({ status, page: String(pageNo), size: "25" })}`,
    pageOf(PaymentRowSchema),
  );
  const href = (p: number) => `/payments?${new URLSearchParams({ status, page: String(p) })}`;

  return (
    <>
      <PageHeader
        title="Payments"
        description="Pro passes paid through Razorpay, in each customer's local currency. Refunds are issued from the Razorpay dashboard."
      />
      <div className="mb-4 flex flex-wrap gap-2" role="group" aria-label="Filter">
        {FILTERS.map((f) => (
          <Link
            key={f.id}
            href={`/payments?status=${f.id}`}
            aria-current={status === f.id ? "page" : undefined}
            className={status === f.id ? "btn-primary" : "btn-secondary"}
          >
            {f.label}
          </Link>
        ))}
      </div>
      {data.items.length === 0 ? (
        <EmptyState
          title={status === "paid" ? "No payments yet" : "Nothing here"}
          message={
            status === "paid"
              ? "Payments appear here when people buy Pro in the app."
              : "No payments match this filter."
          }
        />
      ) : (
        <TableShell>
          <thead>
            <tr>
              <th className={th}>User</th>
              <th className={th}>Plan</th>
              <th className={`${th} text-right`}>Amount</th>
              <th className={th}>Status</th>
              <th className={th}>Razorpay IDs</th>
              <th className={th}>Date</th>
            </tr>
          </thead>
          <tbody>
            {data.items.map((p) => (
              <tr key={p.id} className="hover:bg-surface-2/60">
                <td className={td}>
                  {p.userId ? (
                    <Link href={`/users/${p.userId}`} className="font-semibold hover:underline">
                      {p.userName || p.userPhone}
                    </Link>
                  ) : (
                    <span className="text-muted">Deleted user</span>
                  )}
                </td>
                <td className={`${td} capitalize`}>{p.plan}</td>
                <td className={`${td} tabular text-right font-semibold`}>{money(p.amountMinor, p.currency)}</td>
                <td className={td}>
                  <Badge tone={TONE[p.status]}>{STATUS_LABEL[p.status]}</Badge>
                </td>
                <td className={`${td} tabular text-xs text-muted`}>
                  {p.orderId}
                  {p.paymentId ? <span className="block">{p.paymentId}</span> : null}
                </td>
                <td className={`${td} text-muted`}>{dateTime(p.paidAt ?? p.createdAt)}</td>
              </tr>
            ))}
          </tbody>
        </TableShell>
      )}
      <Pagination page={data.page} size={data.size} total={data.total} href={href} />
    </>
  );
}
