import Link from "next/link";
import type { ReactNode } from "react";

export function PageHeader({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: ReactNode;
}) {
  return (
    <header className="mb-6 flex flex-wrap items-end justify-between gap-4">
      <div>
        <h1 className="font-display text-2xl font-bold tracking-tight sm:text-3xl">{title}</h1>
        {description ? <p className="mt-1 text-sm text-muted">{description}</p> : null}
      </div>
      {action}
    </header>
  );
}

export function Field({
  label,
  htmlFor,
  hint,
  children,
}: {
  label: string;
  htmlFor: string;
  hint?: string;
  children: ReactNode;
}) {
  return (
    <div>
      <label htmlFor={htmlFor} className="mb-1.5 block text-sm font-semibold">
        {label}
      </label>
      {children}
      {hint ? <p className="mt-1.5 text-xs text-muted">{hint}</p> : null}
    </div>
  );
}

type Tone = "neutral" | "accent" | "success" | "danger" | "warning";
const tones: Record<Tone, string> = {
  neutral: "bg-surface-2 text-muted",
  accent: "bg-accent text-on-accent",
  success: "bg-success/12 text-success",
  danger: "bg-danger/12 text-danger",
  warning: "bg-warning/15 text-warning",
};

export function Badge({ tone = "neutral", children }: { tone?: Tone; children: ReactNode }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold whitespace-nowrap ${tones[tone]}`}
    >
      {children}
    </span>
  );
}

export function StatCard({
  label,
  value,
  hint,
  highlight = false,
}: {
  label: string;
  value: string;
  hint?: string;
  highlight?: boolean;
}) {
  return (
    <div className={`card p-5 ${highlight ? "border-transparent bg-accent text-on-accent" : ""}`}>
      <p className={`text-sm font-medium ${highlight ? "opacity-70" : "text-muted"}`}>{label}</p>
      <p className="tabular mt-2 font-display text-3xl font-bold tracking-tight">{value}</p>
      {hint ? (
        <p className={`mt-1 text-xs ${highlight ? "opacity-70" : "text-muted"}`}>{hint}</p>
      ) : null}
    </div>
  );
}

export function EmptyState({
  title,
  message,
  action,
}: {
  title: string;
  message: string;
  action?: ReactNode;
}) {
  return (
    <div className="card grid place-items-center px-6 py-16 text-center">
      <div aria-hidden className="mb-4 grid size-12 place-items-center rounded-full bg-accent text-xl">
        ✦
      </div>
      <p className="font-display text-lg font-semibold">{title}</p>
      <p className="mt-1 max-w-sm text-sm text-muted">{message}</p>
      {action ? <div className="mt-5">{action}</div> : null}
    </div>
  );
}

/** Plain GET form: search works without JavaScript and lives in the URL. */
export function SearchForm({
  placeholder,
  defaultValue,
  children,
}: {
  placeholder: string;
  defaultValue: string;
  children?: ReactNode;
}) {
  return (
    <form role="search" className="mb-4 flex flex-wrap gap-2">
      <label className="sr-only" htmlFor="q">
        Search
      </label>
      <input
        id="q"
        name="q"
        type="search"
        defaultValue={defaultValue}
        placeholder={placeholder}
        className="input max-w-sm flex-1"
      />
      {children}
      <button type="submit" className="btn-secondary">
        Search
      </button>
    </form>
  );
}

export function Pagination({
  page,
  size,
  total,
  href,
}: {
  page: number;
  size: number;
  total: number;
  href: (page: number) => string;
}) {
  const pages = Math.max(1, Math.ceil(total / size));
  if (pages <= 1) return null;
  const from = (page - 1) * size + 1;
  const to = Math.min(total, page * size);
  return (
    <nav aria-label="Pagination" className="mt-4 flex items-center justify-between gap-4 text-sm">
      <p className="tabular text-muted">
        {from}–{to} of {total}
      </p>
      <div className="flex gap-2">
        {page > 1 ? (
          <Link className="btn-secondary" href={href(page - 1)}>
            Previous
          </Link>
        ) : null}
        {page < pages ? (
          <Link className="btn-secondary" href={href(page + 1)}>
            Next
          </Link>
        ) : null}
      </div>
    </nav>
  );
}

export function TableShell({ children }: { children: ReactNode }) {
  return (
    <div className="card overflow-x-auto">
      <table className="w-full min-w-[640px] text-left text-sm">{children}</table>
    </div>
  );
}

export const th = "px-4 py-3 text-xs font-semibold tracking-wide text-muted uppercase";
export const td = "border-t border-border px-4 py-3 align-middle";

export function ErrorNote({ message }: { message: string }) {
  return (
    <div role="alert" className="card border-danger/40 bg-danger/5 p-5 text-sm">
      <p className="font-semibold text-danger">Something went wrong</p>
      <p className="mt-1 text-muted">{message}</p>
    </div>
  );
}
