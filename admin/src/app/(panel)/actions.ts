"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import { z } from "zod";

import type { ActionResult } from "@/lib/action-result";
import { api, ApiError } from "@/lib/api";
import {
  AdminSchema,
  BroadcastSchema,
  ConfigSchema,
  FoodRowSchema,
  UserDetailSchema,
} from "@/lib/schemas";

const Empty = z.unknown();

function fail(e: unknown): ActionResult {
  if (e instanceof ApiError) return { error: e.message };
  throw e; // redirects and unexpected errors propagate
}

const firstIssue = (e: z.ZodError) => e.issues[0]?.message ?? "Check the form and try again.";

// ── Users ────────────────────────────────────────────────────────────────────

const UserPatch = z.object({
  id: z.uuid(),
  field: z.enum(["isPremium", "isBanned", "freeScansLeft"]),
  value: z.string(),
});

export async function updateUser(_: ActionResult, form: FormData): Promise<ActionResult> {
  const p = UserPatch.safeParse(Object.fromEntries(form));
  if (!p.success) return { error: firstIssue(p.error) };
  const { id, field, value } = p.data;
  let body: Record<string, boolean | number>;
  if (field === "freeScansLeft") {
    const n = Number(value);
    if (!Number.isInteger(n) || n < 0 || n > 1000) return { error: "Enter a whole number 0–1000." };
    body = { freeScansLeft: n };
  } else {
    body = { [field]: value === "true" };
  }
  try {
    await api(`/v1/admin/users/${id}`, UserDetailSchema, {
      method: "PATCH",
      body: JSON.stringify(body),
    });
  } catch (e) {
    return fail(e);
  }
  revalidatePath(`/users/${id}`);
  revalidatePath("/users");
  const messages: Record<string, string> = {
    isPremium: value === "true" ? "Pro access granted." : "Pro access removed.",
    isBanned: value === "true" ? "User suspended — they're signed out of the app." : "User reinstated.",
    freeScansLeft: "Free scans updated.",
  };
  return { ok: messages[field] };
}

export async function deleteUser(_: ActionResult, form: FormData): Promise<ActionResult> {
  const id = z.uuid().safeParse(form.get("id"));
  if (!id.success) return { error: "Invalid user." };
  try {
    await api(`/v1/admin/users/${id.data}`, Empty, { method: "DELETE" });
  } catch (e) {
    return fail(e);
  }
  revalidatePath("/users");
  redirect("/users?deleted=1");
}

// ── Meals ────────────────────────────────────────────────────────────────────

export async function deleteMeal(_: ActionResult, form: FormData): Promise<ActionResult> {
  const p = z.object({ userId: z.uuid(), mealId: z.string().min(1).max(80) }).safeParse(
    Object.fromEntries(form),
  );
  if (!p.success) return { error: "Invalid meal." };
  try {
    await api(
      `/v1/admin/meals/${p.data.userId}/${encodeURIComponent(p.data.mealId)}`,
      Empty,
      { method: "DELETE" },
    );
  } catch (e) {
    return fail(e);
  }
  revalidatePath("/meals");
  return { ok: "Meal removed." };
}

// ── Foods ────────────────────────────────────────────────────────────────────

const num = (label: string) =>
  z.coerce.number({ error: `${label} must be a number` }).min(0, `${label} can't be negative`).max(500);

const FoodForm = z.object({
  id: z.string().optional(),
  name: z.string().trim().min(1, "Enter a name").max(120),
  unit: z.string().trim().min(1, "Enter a portion, e.g. “1 bowl (200 g)”").max(80),
  protein: num("Protein"),
  carbs: num("Carbs"),
  fat: num("Fat"),
  brand: z.string().trim().max(80).optional(),
  barcode: z
    .string()
    .trim()
    .regex(/^\d{0,32}$/, "Barcode must be digits only")
    .optional(),
  isActive: z.string().optional(),
});

export async function saveFood(_: ActionResult, form: FormData): Promise<ActionResult> {
  const p = FoodForm.safeParse(Object.fromEntries(form));
  if (!p.success) return { error: firstIssue(p.error) };
  const f = p.data;
  const body = JSON.stringify({
    name: f.name,
    unit: f.unit,
    macros: { p: f.protein, c: f.carbs, f: f.fat },
    brand: f.brand || null,
    barcode: f.barcode || null,
    isActive: f.isActive === "on",
  });
  try {
    if (f.id) {
      await api(`/v1/admin/foods/${Number(f.id)}`, FoodRowSchema, { method: "PUT", body });
    } else {
      await api("/v1/admin/foods", FoodRowSchema, { method: "POST", body });
    }
  } catch (e) {
    return fail(e);
  }
  revalidatePath("/foods");
  redirect(`/foods?saved=${encodeURIComponent(f.name)}`);
}

export async function approveFood(_: ActionResult, form: FormData): Promise<ActionResult> {
  const id = z.coerce.number().int().positive().safeParse(form.get("id"));
  if (!id.success) return { error: "Invalid food." };
  try {
    await api(`/v1/admin/foods/${id.data}/approve`, FoodRowSchema, { method: "POST" });
  } catch (e) {
    return fail(e);
  }
  revalidatePath("/foods");
  revalidatePath(`/foods/${id.data}`);
  return { ok: "Approved — the AI badge is gone from the app." };
}

export async function deleteFood(_: ActionResult, form: FormData): Promise<ActionResult> {
  const id = z.coerce.number().int().positive().safeParse(form.get("id"));
  if (!id.success) return { error: "Invalid food." };
  try {
    await api(`/v1/admin/foods/${id.data}`, Empty, { method: "DELETE" });
  } catch (e) {
    return fail(e);
  }
  revalidatePath("/foods");
  redirect("/foods?deleted=1");
}

// ── Broadcasts ───────────────────────────────────────────────────────────────

const BroadcastForm = z.object({
  title: z.string().trim().min(1, "Add a title").max(120, "Keep the title under 120 characters"),
  body: z.string().trim().min(1, "Write a message").max(500, "Keep the message under 500 characters"),
  kind: z.enum(["tip", "report", "streak", "pro"]),
  segment: z.enum(["all", "premium", "free"]),
});

export async function sendBroadcast(_: ActionResult, form: FormData): Promise<ActionResult> {
  const p = BroadcastForm.safeParse(Object.fromEntries(form));
  if (!p.success) return { error: firstIssue(p.error) };
  let sent;
  try {
    sent = await api("/v1/admin/broadcasts", BroadcastSchema, {
      method: "POST",
      body: JSON.stringify(p.data),
    });
  } catch (e) {
    return fail(e);
  }
  revalidatePath("/broadcasts");
  return { ok: `Sent to ${sent.recipients} ${sent.recipients === 1 ? "person" : "people"}.` };
}

// ── Settings ─────────────────────────────────────────────────────────────────

const ConfigForm = z.object({
  free_scan_allowance: z.coerce.number().int().min(0, "Use 0–100").max(100, "Use 0–100"),
  ai_daily_limit_free: z.coerce.number().int().min(0, "Use 0–1000").max(1000, "Use 0–1000"),
  min_app_version: z.string().trim().regex(/^\d+\.\d+\.\d+$/, "Version must look like 1.2.3"),
  support_email: z.email("Enter a valid support email"),
  maintenance_message: z.string().trim().max(200),
  maintenance_mode: z.string().optional(),
});

export async function saveConfig(_: ActionResult, form: FormData): Promise<ActionResult> {
  const p = ConfigForm.safeParse(Object.fromEntries(form));
  if (!p.success) return { error: firstIssue(p.error) };
  const c = p.data;
  try {
    await api("/v1/admin/config", ConfigSchema, {
      method: "PUT",
      body: JSON.stringify({
        free_scan_allowance: c.free_scan_allowance,
        ai_daily_limit_free: c.ai_daily_limit_free,
        min_app_version: c.min_app_version,
        support_email: c.support_email,
        maintenance_message: c.maintenance_message,
        maintenance_mode: c.maintenance_mode === "on",
      }),
    });
  } catch (e) {
    return fail(e);
  }
  revalidatePath("/settings");
  return { ok: "Settings saved. The app picks them up on next launch." };
}

const NewAdmin = z.object({
  email: z.email("Enter a valid email"),
  name: z.string().trim().max(80),
  password: z.string().min(10, "Password must be at least 10 characters"),
  role: z.enum(["owner", "editor"]),
});

export async function createAdmin(_: ActionResult, form: FormData): Promise<ActionResult> {
  const p = NewAdmin.safeParse(Object.fromEntries(form));
  if (!p.success) return { error: firstIssue(p.error) };
  try {
    await api("/v1/admin/admins", AdminSchema, { method: "POST", body: JSON.stringify(p.data) });
  } catch (e) {
    return fail(e);
  }
  revalidatePath("/settings");
  return { ok: `${p.data.email} can now sign in.` };
}

export async function removeAdmin(_: ActionResult, form: FormData): Promise<ActionResult> {
  const id = z.uuid().safeParse(form.get("id"));
  if (!id.success) return { error: "Invalid admin." };
  try {
    await api(`/v1/admin/admins/${id.data}`, Empty, { method: "DELETE" });
  } catch (e) {
    return fail(e);
  }
  revalidatePath("/settings");
  return { ok: "Admin removed." };
}
