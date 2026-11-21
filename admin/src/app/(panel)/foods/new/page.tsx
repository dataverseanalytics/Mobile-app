import type { Metadata } from "next";
import Link from "next/link";

import { PageHeader } from "@/components/ui";

import { FoodForm } from "../food-form";

export const metadata: Metadata = { title: "Add food" };

export default function NewFoodPage() {
  return (
    <>
      <Link href="/foods" className="text-sm font-medium text-muted hover:text-text">
        ← Food database
      </Link>
      <div className="mt-3">
        <PageHeader title="Add food" description="It becomes searchable in the app immediately." />
      </div>
      <FoodForm />
    </>
  );
}
