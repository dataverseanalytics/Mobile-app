import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";

import { ActionForm, ConfirmAction, SubmitButton } from "@/components/forms";
import { PageHeader } from "@/components/ui";
import { api, ApiError } from "@/lib/api";
import { FoodRowSchema } from "@/lib/schemas";

import { approveFood, deleteFood } from "../../actions";
import { FoodForm } from "../food-form";

export const metadata: Metadata = { title: "Edit food" };

export default async function EditFoodPage({ params }: PageProps<"/foods/[id]">) {
  const { id } = await params;
  if (!/^\d+$/.test(id)) notFound();
  let food;
  try {
    food = await api(`/v1/admin/foods/${id}`, FoodRowSchema);
  } catch (e) {
    if (e instanceof ApiError && e.status === 404) notFound();
    throw e;
  }
  return (
    <>
      <Link href="/foods" className="text-sm font-medium text-muted hover:text-text">
        ← Food database
      </Link>
      <div className="mt-3">
        <PageHeader title={food.name} description="Changes appear in app search right away." />
      </div>
      {food.source === "ai" && !food.reviewed ? (
        <ActionForm
          action={approveFood}
          className="card mb-4 flex max-w-2xl flex-wrap items-center justify-between gap-3 border-warning/40 bg-warning/5 p-4"
        >
          <input type="hidden" name="id" value={food.id} />
          <p className="text-sm">
            <span className="font-semibold">AI estimate.</span> Check the portion and numbers, then approve — or correct
            them below and save.
          </p>
          <SubmitButton variant="secondary" pendingLabel="Approving…">
            Approve as is
          </SubmitButton>
        </ActionForm>
      ) : null}
      <FoodForm food={food} />
      <div className="mt-6 max-w-2xl">
        <ConfirmAction
          action={deleteFood}
          hidden={{ id: String(food.id) }}
          label="Delete food…"
          confirmLabel={`Delete “${food.name}”`}
          warning="People will no longer find it in search. Meals already logged keep their numbers. Prefer unticking “Visible in the app” if you might need it again."
        />
      </div>
    </>
  );
}
