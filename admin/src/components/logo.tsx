export function Logo({ compact = false }: { compact?: boolean }) {
  return (
    <span className="inline-flex items-center gap-2.5" aria-label="NutriLens Admin">
      <span
        aria-hidden
        className="grid size-9 place-items-center rounded-[11px] bg-[#14140f]"
      >
        <span className="relative size-[18px] rounded-full border-[3px] border-accent">
          <span className="absolute top-0 right-0 size-1 rounded-full bg-accent" />
        </span>
      </span>
      {compact ? null : (
        <span className="font-display text-lg font-bold tracking-tight">
          NutriLens <span className="font-sans text-sm font-medium text-muted">Admin</span>
        </span>
      )}
    </span>
  );
}
