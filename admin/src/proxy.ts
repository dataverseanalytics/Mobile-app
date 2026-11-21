import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/**
 * Coarse gate only: no session cookie → login page. Real authorization
 * happens in the backend on every API call.
 */
export function proxy(request: NextRequest) {
  if (!request.cookies.has("nl_admin")) {
    const url = new URL("/login", request.url);
    return NextResponse.redirect(url);
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/((?!login|_next/static|_next/image|favicon.ico).*)"],
};
