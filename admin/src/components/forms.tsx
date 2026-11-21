"use client";

import { useActionState, useState, type ReactNode } from "react";
import { useFormStatus } from "react-dom";

import type { ActionResult } from "@/lib/action-result";

export function SubmitButton({
  children,
  pendingLabel,
  variant = "primary",
}: {
  children: ReactNode;
  pendingLabel: string;
  variant?: "primary" | "secondary" | "danger";
}) {
  const { pending } = useFormStatus();
  return (
    <button type="submit" disabled={pending} className={`btn-${variant}`}>
      {pending ? pendingLabel : children}
    </button>
  );
}

/**
 * A form bound to a Server Action that returns `{ok}` or `{error}`.
 * The result is shown inline next to the controls (never only a toast),
 * and inputs keep their values on error.
 */
export function ActionForm({
  action,
  children,
  className,
}: {
  action: (prev: ActionResult, form: FormData) => Promise<ActionResult>;
  children: ReactNode;
  className?: string;
}) {
  const [state, formAction] = useActionState(action, {});
  return (
    <form action={formAction} className={className}>
      {children}
      {state.error ? (
        <p role="alert" className="mt-3 text-sm text-danger">
          {state.error}
        </p>
      ) : null}
      {state.ok ? (
        <p role="status" className="mt-3 text-sm text-success">
          {state.ok}
        </p>
      ) : null}
    </form>
  );
}

/**
 * Destructive action in two deliberate steps. The confirm button names the
 * action ("Delete user") — no generic "Are you sure? OK".
 */
export function ConfirmAction({
  action,
  label,
  confirmLabel,
  warning,
  hidden,
}: {
  action: (prev: ActionResult, form: FormData) => Promise<ActionResult>;
  label: string;
  confirmLabel: string;
  warning: string;
  hidden?: Record<string, string>;
}) {
  const [armed, setArmed] = useState(false);
  const [state, formAction] = useActionState(action, {});
  if (!armed) {
    return (
      <button type="button" className="btn-danger" onClick={() => setArmed(true)}>
        {label}
      </button>
    );
  }
  return (
    <form action={formAction} className="rounded-2xl border border-danger/40 bg-danger/5 p-4">
      {Object.entries(hidden ?? {}).map(([k, v]) => (
        <input key={k} type="hidden" name={k} value={v} />
      ))}
      <p className="text-sm">{warning}</p>
      <div className="mt-3 flex flex-wrap gap-2">
        <SubmitButton variant="danger" pendingLabel="Working…">
          {confirmLabel}
        </SubmitButton>
        <button type="button" className="btn-secondary" onClick={() => setArmed(false)}>
          Cancel
        </button>
      </div>
      {state.error ? (
        <p role="alert" className="mt-3 text-sm text-danger">
          {state.error}
        </p>
      ) : null}
    </form>
  );
}
