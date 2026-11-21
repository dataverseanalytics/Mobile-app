"use server";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";

import { errorDetail, publicPost, SESSION_COOKIE } from "@/lib/api";
import { LoginResponse } from "@/lib/schemas";

export type LoginState = { error?: string; email?: string };

const Input = z.object({
  email: z.email("Enter a valid email address"),
  password: z.string().min(1, "Enter your password"),
});

export async function login(_: LoginState, form: FormData): Promise<LoginState> {
  const email = String(form.get("email") ?? "").trim();
  const parsed = Input.safeParse({ email, password: form.get("password") });
  if (!parsed.success) return { error: parsed.error.issues[0].message, email };

  let res: Response;
  try {
    res = await publicPost("/v1/admin/auth/login", parsed.data);
  } catch {
    return { error: "Can't reach the server. Is the backend running?", email };
  }
  if (!res.ok) return { error: await errorDetail(res), email };

  const { accessToken } = LoginResponse.parse(await res.json());
  (await cookies()).set(SESSION_COOKIE, accessToken, {
    httpOnly: true,
    // HTTPS-only in production; COOKIE_SECURE=false allows plain-HTTP setups (IP:port, no domain yet).
    secure: process.env.COOKIE_SECURE ? process.env.COOKIE_SECURE === "true" : process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 60 * 60 * 12, // matches the backend's admin token lifetime
  });
  redirect("/");
}

export async function logout(): Promise<void> {
  (await cookies()).delete(SESSION_COOKIE);
  redirect("/login");
}
