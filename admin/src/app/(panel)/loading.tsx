/** Skeleton shaped like a typical admin page: header, stat row, table. */
export default function Loading() {
  return (
    <div aria-busy="true" aria-label="Loading" className="animate-pulse">
      <div className="mb-6 h-9 w-56 rounded-lg bg-surface-2" />
      <div className="mb-6 grid grid-cols-2 gap-4 xl:grid-cols-4">
        {["a", "b", "c", "d"].map((k) => (
          <div key={k} className="h-28 rounded-[var(--radius-card)] bg-surface-2" />
        ))}
      </div>
      <div className="h-80 rounded-[var(--radius-card)] bg-surface-2" />
    </div>
  );
}
