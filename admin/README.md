# NutriLens Admin

Next.js 16 (App Router, Cache Components) · React 19 · TypeScript (strict) · Tailwind 4 · zod.

```bash
npm install
npm run dev        # http://localhost:3000
npm run build && npm start
```

`.env.local`:

```
API_URL=http://localhost:8001   # server-only; never sent to the browser
```

## Pages

| Page | What admins do |
|---|---|
| Dashboard | Users, daily activity, Pro conversion, meals and AI-scan trends over 30 days, top countries |
| Users | Search and filter; open a user to grant or remove Pro, set free scans, suspend, or delete (owner only) |
| Payments | Razorpay payments (paid, unfinished, failed) with order and payment IDs; revenue on the dashboard |
| Meals | Every logged meal; remove inappropriate entries |
| Food database | Add, edit, hide or delete the foods the app searches, including barcodes |
| Notifications | Broadcast to everyone, Pro users or free users; see the history and how many people each reached |
| AI scans | Outcome, speed and errors for every scan |
| Settings | Free-scan allowance, minimum app version, maintenance mode, Pro plan prices (read-only, set on the server), team (owners invite editors and owners) |

## How it works

| Area | Approach |
|---|---|
| Sign-in | Login stores the admin token in an **httpOnly** cookie. Only `src/lib/api.ts` (`server-only`) reads it, and the backend authorizes every call. |
| Data loading | Pages are Server Components that fetch on the server. Responses are checked against zod schemas, so if the API changes shape you see a clear error, not a broken page. |
| Changes | Made through Server Actions (`src/app/(panel)/actions.ts`). Input is validated, results appear next to the form, and destructive actions need a second, named confirmation. |
| URLs | Search, filters and pagination live in the URL, so links can be shared and the back button works. |
