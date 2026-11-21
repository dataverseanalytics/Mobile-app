import Link from "next/link";

import { ActionForm, SubmitButton } from "@/components/forms";
import { Field } from "@/components/ui";
import type { FoodRow } from "@/lib/schemas";

import { saveFood } from "../actions";

/** Shared create/edit form. Labels always visible; values kept on error. */
export function FoodForm({ food }: { food?: FoodRow }) {
  return (
    <ActionForm action={saveFood} className="card max-w-2xl space-y-5 p-6">
      {food ? <input type="hidden" name="id" value={food.id} /> : null}
      <div className="grid gap-5 sm:grid-cols-2">
        <Field label="Name" htmlFor="name">
          <input id="name" name="name" required maxLength={120} defaultValue={food?.name} className="input" />
        </Field>
        <Field label="Portion" htmlFor="unit" hint="Shown to users, e.g. “1 bowl (200 g)”">
          <input id="unit" name="unit" required maxLength={80} defaultValue={food?.unit} className="input" />
        </Field>
      </div>
      <fieldset>
        <legend className="mb-1.5 text-sm font-semibold">Nutrition per portion (grams)</legend>
        <div className="grid grid-cols-3 gap-3">
          {(
            [
              ["protein", "Protein", food?.macros.p, "bg-protein"],
              ["carbs", "Carbs", food?.macros.c, "bg-carbs"],
              ["fat", "Fat", food?.macros.f, "bg-fat"],
            ] as const
          ).map(([name, label, value, dot]) => (
            <div key={name}>
              <label htmlFor={name} className="mb-1 flex items-center gap-1.5 text-xs text-muted">
                <span aria-hidden className={`size-2 rounded-full ${dot}`} />
                {label}
              </label>
              <input
                id={name}
                name={name}
                type="number"
                inputMode="decimal"
                step="0.1"
                min={0}
                max={500}
                required
                defaultValue={value}
                className="input tabular"
              />
            </div>
          ))}
        </div>
        <p className="mt-1.5 text-xs text-muted">Calories are calculated from these (4/4/9 kcal per gram).</p>
      </fieldset>
      <div className="grid gap-5 sm:grid-cols-2">
        <Field label="Brand (optional)" htmlFor="brand">
          <input id="brand" name="brand" maxLength={80} defaultValue={food?.brand ?? ""} className="input" />
        </Field>
        <Field label="Barcode (optional)" htmlFor="barcode" hint="EAN/UPC digits for barcode scanning">
          <input
            id="barcode"
            name="barcode"
            inputMode="numeric"
            pattern="\d*"
            maxLength={32}
            defaultValue={food?.barcode ?? ""}
            className="input tabular"
          />
        </Field>
      </div>
      <label className="flex min-h-11 items-center gap-3 text-sm">
        <input
          type="checkbox"
          name="isActive"
          defaultChecked={food?.isActive ?? true}
          className="size-5 accent-[var(--text)]"
        />
        Visible in the app
      </label>
      <div className="flex flex-wrap gap-2 border-t border-border pt-5">
        <SubmitButton pendingLabel="Saving…">{food ? "Save changes" : "Add food"}</SubmitButton>
        <Link href="/foods" className="btn-secondary">
          Cancel
        </Link>
      </div>
    </ActionForm>
  );
}
