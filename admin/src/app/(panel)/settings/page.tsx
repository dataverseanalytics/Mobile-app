import type { Metadata } from "next";
import { z } from "zod";

import { ActionForm, ConfirmAction, SubmitButton } from "@/components/forms";
import { Badge, Field, PageHeader } from "@/components/ui";
import { api, getCurrentAdmin } from "@/lib/api";
import { date } from "@/lib/format";
import { AdminSchema, ConfigSchema, PricingTierSchema } from "@/lib/schemas";

import { createAdmin, removeAdmin, saveConfig } from "../actions";

export const metadata: Metadata = { title: "Settings" };

export default async function SettingsPage() {
  const [config, admins, me, pricing] = await Promise.all([
    api("/v1/admin/config", ConfigSchema),
    api("/v1/admin/admins", z.array(AdminSchema)),
    getCurrentAdmin(),
    api("/v1/admin/pricing", z.array(PricingTierSchema)),
  ]);
  const isOwner = me.role === "owner";

  return (
    <>
      <PageHeader title="Settings" description="App-wide settings and who can access this panel." />
      {!isOwner ? (
        <p className="mb-4 rounded-xl bg-warning/10 px-4 py-3 text-sm">
          You&apos;re an editor. Only owners can change app settings or manage the team.
        </p>
      ) : null}

      <div className="grid gap-6 xl:grid-cols-2">
        <section aria-labelledby="app-settings">
          <h2 id="app-settings" className="mb-3 font-semibold">
            App settings
          </h2>
          <ActionForm action={saveConfig} className="card space-y-5 p-6">
            <fieldset disabled={!isOwner} className="space-y-5 disabled:opacity-60">
              <div className="grid gap-5 sm:grid-cols-2">
                <Field label="Free scans for new users" htmlFor="free_scan_allowance" hint="0–100">
                  <input
                    id="free_scan_allowance"
                    name="free_scan_allowance"
                    type="number"
                    min={0}
                    max={100}
                    defaultValue={config.free_scan_allowance}
                    className="input tabular"
                  />
                </Field>
                <Field label="Minimum app version" htmlFor="min_app_version" hint="Older apps are asked to update">
                  <input
                    id="min_app_version"
                    name="min_app_version"
                    defaultValue={config.min_app_version}
                    className="input tabular"
                  />
                </Field>
              </div>
              <Field
                label="AI requests per day (free users)"
                htmlFor="ai_daily_limit_free"
                hint="Meal descriptions + suggestions. Pro users get 200. Photo scans use the free-scan allowance."
              >
                <input
                  id="ai_daily_limit_free"
                  name="ai_daily_limit_free"
                  type="number"
                  min={0}
                  max={1000}
                  defaultValue={config.ai_daily_limit_free}
                  className="input tabular"
                />
              </Field>
              <Field label="Support email" htmlFor="support_email">
                <input
                  id="support_email"
                  name="support_email"
                  type="email"
                  defaultValue={config.support_email}
                  className="input"
                />
              </Field>
              <div className="rounded-2xl border border-border p-4">
                <label className="flex min-h-11 items-center gap-3 text-sm font-semibold">
                  <input
                    type="checkbox"
                    name="maintenance_mode"
                    defaultChecked={config.maintenance_mode}
                    className="size-5 accent-[var(--text)]"
                  />
                  Maintenance mode
                </label>
                <Field label="Maintenance message" htmlFor="maintenance_message">
                  <input
                    id="maintenance_message"
                    name="maintenance_message"
                    maxLength={200}
                    defaultValue={config.maintenance_message}
                    placeholder="We're upgrading — back in 15 minutes."
                    className="input"
                  />
                </Field>
              </div>
              <SubmitButton pendingLabel="Saving…">Save settings</SubmitButton>
            </fieldset>
          </ActionForm>
        </section>

        <section aria-labelledby="team" className="space-y-4">
          <div className="card overflow-x-auto p-5">
            <h2 className="font-semibold">Pro prices by country</h2>
            <p className="mt-1 text-xs text-muted">
              Picked from the customer&apos;s verified phone number, charged in local currency through
              Razorpay. Edit in backend/app/services/pricing.py.
            </p>
            <table className="mt-3 w-full min-w-[420px] text-sm">
              <thead>
                <tr className="text-left text-xs text-muted">
                  <th className="py-2 font-semibold">Region</th>
                  <th className="py-2 text-right font-semibold">Yearly</th>
                  <th className="py-2 text-right font-semibold">Monthly</th>
                  <th className="py-2 text-right font-semibold">Weekly</th>
                </tr>
              </thead>
              <tbody>
                {pricing.map((t) => (
                  <tr key={t.tier} className="border-t border-border">
                    <td className="py-2.5 pr-3">
                      <span className="font-medium">{t.currency}</span>
                      <span className="block max-w-[14rem] truncate text-xs text-muted" title={t.countries.join(", ")}>
                        {t.countries.join(", ")}
                      </span>
                    </td>
                    {t.prices.map((p) => (
                      <td key={p.plan} className="tabular py-2.5 pl-4 text-right font-semibold whitespace-nowrap">
                        {p.label}
                      </td>
                    ))}
                  </tr>
                ))}
              </tbody>
            </table>
            <p className="mt-3 text-xs text-muted">
              Non-INR prices need International Payments enabled in Razorpay. Customers outside India pay by card.
            </p>
          </div>

          <ul className="card divide-y divide-border">
            {admins.map((a) => (
              <li key={a.id} className="flex flex-wrap items-center gap-3 p-4">
                <div className="min-w-0 flex-1">
                  <p className="truncate font-medium">
                    {a.name || a.email} {a.id === me.id ? <span className="text-muted">(you)</span> : null}
                  </p>
                  <p className="truncate text-xs text-muted">
                    {a.email} · since {date(a.createdAt)}
                  </p>
                </div>
                <Badge tone={a.role === "owner" ? "accent" : "neutral"}>{a.role}</Badge>
                {isOwner && a.id !== me.id ? (
                  <ConfirmAction
                    action={removeAdmin}
                    hidden={{ id: a.id }}
                    label="Remove"
                    confirmLabel={`Remove ${a.email}`}
                    warning="They'll lose access to this panel immediately."
                  />
                ) : null}
              </li>
            ))}
          </ul>

          {isOwner ? (
            <ActionForm action={createAdmin} className="card space-y-4 p-6">
              <h3 className="font-semibold">Invite a teammate</h3>
              <div className="grid gap-4 sm:grid-cols-2">
                <Field label="Email" htmlFor="new-email">
                  <input id="new-email" name="email" type="email" required className="input" />
                </Field>
                <Field label="Name" htmlFor="new-name">
                  <input id="new-name" name="name" maxLength={80} className="input" />
                </Field>
                <Field label="Temporary password" htmlFor="new-password" hint="At least 10 characters">
                  <input
                    id="new-password"
                    name="password"
                    type="password"
                    autoComplete="new-password"
                    minLength={10}
                    required
                    className="input"
                  />
                </Field>
                <Field label="Role" htmlFor="new-role">
                  <select id="new-role" name="role" defaultValue="editor" className="input">
                    <option value="editor">Editor — manage users &amp; content</option>
                    <option value="owner">Owner — everything, incl. settings</option>
                  </select>
                </Field>
              </div>
              <SubmitButton pendingLabel="Adding…">Add admin</SubmitButton>
            </ActionForm>
          ) : null}
        </section>
      </div>
    </>
  );
}
