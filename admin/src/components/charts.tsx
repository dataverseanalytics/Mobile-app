import type { DayPoint } from "@/lib/schemas";

/** Small server-rendered bar chart (no chart library needed). */
export function BarChart({
  title,
  points,
  unit,
}: {
  title: string;
  points: DayPoint[];
  unit: string;
}) {
  const max = Math.max(1, ...points.map((p) => p.value));
  const total = points.reduce((a, p) => a + p.value, 0);
  const w = 600;
  const h = 140;
  const gap = 4;
  const bw = (w - gap * (points.length - 1)) / points.length;
  const last = points.at(-1);
  return (
    <figure className="card p-5">
      <figcaption className="flex items-baseline justify-between gap-4">
        <span className="font-semibold">{title}</span>
        <span className="tabular text-sm text-muted">
          {total} {unit} · 30 days
        </span>
      </figcaption>
      <svg
        viewBox={`0 0 ${w} ${h}`}
        className="mt-4 h-36 w-full"
        role="img"
        aria-label={`${title}: ${total} ${unit} over 30 days${last ? `, ${last.value} today` : ""}`}
        preserveAspectRatio="none"
      >
        {points.map((p, i) => {
          const bh = Math.max(2, (p.value / max) * (h - 4));
          const isLast = i === points.length - 1;
          return (
            <rect
              key={p.day}
              x={i * (bw + gap)}
              y={h - bh}
              width={bw}
              height={bh}
              rx={3}
              className={isLast ? "fill-accent" : "fill-text/80"}
            >
              <title>{`${p.day}: ${p.value}`}</title>
            </rect>
          );
        })}
      </svg>
      <div className="mt-2 flex justify-between text-xs text-muted">
        <span>{points[0]?.day.slice(5)}</span>
        <span>Today</span>
      </div>
    </figure>
  );
}
