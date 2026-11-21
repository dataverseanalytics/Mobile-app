const nf = new Intl.NumberFormat("en-IN");
const df = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric" });
const dtf = new Intl.DateTimeFormat("en-GB", {
  day: "numeric",
  month: "short",
  hour: "2-digit",
  minute: "2-digit",
});

export const num = (n: number) => nf.format(Math.round(n));
export const date = (iso: string) => df.format(new Date(iso));
export const dateTime = (iso: string) => dtf.format(new Date(iso));
/** Minor units in any currency → "₹2,499", "$39.99", "€7.99". */
export function money(minor: number, currency: string): string {
  return new Intl.NumberFormat(currency === "INR" ? "en-IN" : "en-US", {
    style: "currency",
    currency,
    maximumFractionDigits: currency === "INR" ? 0 : 2,
  }).format(minor / 100);
}

/** Per-currency totals, e.g. "₹1,24,950 · $79.90". */
export function moneyList(rows: { currency: string; amountMinor: number }[]): string {
  return rows.length ? rows.map((r) => money(r.amountMinor, r.currency)).join(" · ") : money(0, "INR");
}
export const pct = (n: number) => `${Math.round(n * 1000) / 10}%`;

export function ago(iso: string): string {
  const s = (Date.now() - new Date(iso).getTime()) / 1000;
  if (s < 60) return "just now";
  if (s < 3600) return `${Math.floor(s / 60)}m ago`;
  if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
  if (s < 86400 * 30) return `${Math.floor(s / 86400)}d ago`;
  return date(iso);
}

/** Country code → flag emoji. */
export function flag(code: string): string {
  if (!/^[A-Z]{2}$/.test(code)) return "🌐";
  return String.fromCodePoint(...[...code].map((c) => 0x1f1e6 + c.charCodeAt(0) - 65));
}

/** Integer page number from a search param, never below 1. */
export function pageParam(v: string | string[] | undefined): number {
  const n = Number(Array.isArray(v) ? v[0] : v);
  return Number.isFinite(n) && n >= 1 ? Math.floor(n) : 1;
}

export function strParam(v: string | string[] | undefined): string {
  return (Array.isArray(v) ? v[0] : v) ?? "";
}
