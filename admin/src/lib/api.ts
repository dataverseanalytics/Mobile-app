import "server-only";

import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { z } from "zod";

import { AdminSchema } from "./schemas";

/** Backend base URL. Server-only: never exposed to the browser. */
const API_URL = process.env.API_URL ?? "http://localhost:8001";
export const SESSION_COOKIE = "nl_admin";

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
  ) {
    super(message);
  }
}

/** FastAPI errors: `{detail: "..."}` or validation `{detail: [{msg}]}`. */
const ErrorBody = z.object({
  detail: z.union([z.string(), z.array(z.object({ msg: z.string() })).min(1)]),
});

async function detail(res: Response): Promise<string> {
  const parsed = ErrorBody.safeParse(await res.json().catch(() => null));
  if (parsed.success) {
    const d = parsed.data.detail;
    return typeof d === "string" ? d : d[0].msg;
  }
  return res.status >= 500 ? "The server had a problem. Please try again." : "Request failed.";
}

/**
 * Calls the admin API with the signed-in admin's token (httpOnly cookie).
 * The backend authorizes every request; an expired session sends the
 * admin back to the login page.
 */
export async function api<T extends z.ZodType>(
  path: string,
  schema: T,
  init: RequestInit = {},
): Promise<z.infer<T>> {
  const token = (await cookies()).get(SESSION_COOKIE)?.value;
  if (!token) redirect("/login");

  let res: Response;
  try {
    res = await fetch(`${API_URL}${path}`, {
      ...init,
      cache: "no-store",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
        ...init.headers,
      },
    });
  } catch {
    throw new ApiError(503, `Can't reach the API at ${API_URL}. Is the backend running?`);
  }
  if (res.status === 401) redirect("/login?expired=1");
  if (!res.ok) throw new ApiError(res.status, await detail(res));
  const body: unknown = res.status === 204 ? undefined : await res.json();
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    // Contract drift between panel and API: log details, show a clear message.
    console.error(`Unexpected response from ${path}`, parsed.error.issues);
    throw new ApiError(502, `Unexpected response from the API (${path}). Is the backend up to date?`);
  }
  return parsed.data;
}

/** Unauthenticated call used only by the login action. */
export async function publicPost(path: string, body: unknown): Promise<Response> {
  return fetch(`${API_URL}${path}`, {
    method: "POST",
    cache: "no-store",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

export async function getCurrentAdmin() {
  return api("/v1/admin/me", AdminSchema);
}

export { detail as errorDetail };
