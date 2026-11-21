import type { Metadata } from "next";

import { Logo } from "@/components/logo";

import { LoginForm } from "./login-form";

export const metadata: Metadata = { title: "Sign in" };

export default function LoginPage() {
  return (
    <main className="grid min-h-dvh place-items-center px-4 py-12">
      <div className="w-full max-w-sm">
        <Logo />
        <h1 className="mt-8 font-display text-3xl font-bold tracking-tight">Admin sign in</h1>
        <p className="mt-2 text-muted">Manage users, foods, notifications and app settings.</p>
        <LoginForm />
      </div>
    </main>
  );
}
