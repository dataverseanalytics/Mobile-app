"use client";

export default function PanelError({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div role="alert" className="card max-w-xl border-danger/40 p-6">
      <h1 className="font-display text-xl font-bold">This page couldn&apos;t load</h1>
      <p className="mt-2 text-sm text-muted">
        {error.message || "An unexpected error occurred."} Your data is safe — try again, or check
        that the backend is running.
      </p>
      <button type="button" onClick={reset} className="btn-primary mt-5">
        Try again
      </button>
    </div>
  );
}
