import type { Metadata } from "next";
import { z } from "zod";

import { ActionForm, SubmitButton } from "@/components/forms";
import { Badge, Field, PageHeader } from "@/components/ui";
import { api } from "@/lib/api";
import { dateTime } from "@/lib/format";
import { BroadcastSchema } from "@/lib/schemas";

import { sendBroadcast } from "../actions";

export const metadata: Metadata = { title: "Notifications" };

const SEGMENT_LABEL: Record<string, string> = { all: "Everyone", premium: "Pro users", free: "Free users" };

export default async function BroadcastsPage() {
  const history = await api("/v1/admin/broadcasts", z.array(BroadcastSchema));
  return (
    <>
      <PageHeader
        title="Notifications"
        description="Send a message to people's in-app inbox."
      />
      <div className="grid gap-6 xl:grid-cols-5">
        <section className="xl:col-span-2" aria-labelledby="compose">
          <h2 id="compose" className="sr-only">
            Compose
          </h2>
          <ActionForm action={sendBroadcast} className="card space-y-4 p-6">
            <Field label="Title" htmlFor="title">
              <input id="title" name="title" required maxLength={120} className="input" />
            </Field>
            <Field label="Message" htmlFor="body" hint="Up to 500 characters. Keep it short and useful.">
              <textarea id="body" name="body" required maxLength={500} rows={4} className="input" />
            </Field>
            <div className="grid grid-cols-2 gap-3">
              <Field label="Audience" htmlFor="segment">
                <select id="segment" name="segment" defaultValue="all" className="input">
                  <option value="all">Everyone</option>
                  <option value="free">Free users</option>
                  <option value="premium">Pro users</option>
                </select>
              </Field>
              <Field label="Type" htmlFor="kind">
                <select id="kind" name="kind" defaultValue="tip" className="input">
                  <option value="tip">Tip</option>
                  <option value="report">Report</option>
                  <option value="streak">Streak</option>
                  <option value="pro">Pro offer</option>
                </select>
              </Field>
            </div>
            <p className="text-xs text-muted">
              Suspended accounts are skipped. Messages appear in the app&apos;s Notifications screen.
            </p>
            <SubmitButton pendingLabel="Sending…">Send notification</SubmitButton>
          </ActionForm>
        </section>

        <section className="xl:col-span-3" aria-labelledby="sent">
          <h2 id="sent" className="mb-3 font-semibold">
            Sent
          </h2>
          {history.length === 0 ? (
            <p className="card p-6 text-sm text-muted">
              Nothing sent yet. Your first message will show up here with its reach.
            </p>
          ) : (
            <ul className="space-y-3">
              {history.map((b) => (
                <li key={b.id} className="card p-5">
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <p className="font-semibold">{b.title}</p>
                    <span className="text-xs text-muted">{dateTime(b.createdAt)}</span>
                  </div>
                  <p className="mt-1 text-sm text-muted">{b.body}</p>
                  <div className="mt-3 flex flex-wrap gap-1.5">
                    <Badge>{SEGMENT_LABEL[b.segment] ?? b.segment}</Badge>
                    <Badge tone="accent">
                      {b.recipients} {b.recipients === 1 ? "person" : "people"}
                    </Badge>
                    <Badge>{b.adminEmail}</Badge>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </section>
      </div>
    </>
  );
}
