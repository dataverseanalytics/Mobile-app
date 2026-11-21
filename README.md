# NutriLens

AI calorie and macro tracker: snap a meal, get nutrition in seconds.

```
New_rendom/
├─ nutrilens/   Flutter app (Android · iOS · web)
├─ backend/     FastAPI + PostgreSQL API (auth, sync, AI scan, admin API)
└─ admin/       Next.js admin panel
```

## Run everything locally

You need Docker Desktop, Python 3.12, Node 20+ and Flutter 3.47+.

**1. Database and API (port 8001)**

```bash
cd backend
docker compose up -d db                   # PostgreSQL on localhost:5434
python -m venv .venv && .venv/Scripts/pip install -r requirements.txt   # macOS/Linux: .venv/bin/
.venv/Scripts/alembic upgrade head        # create tables
.venv/Scripts/python -m app.seed          # admin login + starter food database
.venv/Scripts/uvicorn app.main:app --port 8001 --reload
```

API docs: http://localhost:8001/docs

**2. Admin panel (port 3000)**

```bash
cd admin
npm install
npm run dev
```

Open http://localhost:3000 and sign in with `admin@nutrilens.app` / `ChangeMe123!` (from `backend/.env`).

**3. App connected to the API**

```bash
cd nutrilens
flutter run -d chrome --dart-define=API_URL=http://localhost:8001
# Android emulator: --dart-define=API_URL=http://10.0.2.2:8001
# Real phone: use your PC's LAN IP, e.g. http://192.168.1.20:8001
```

Sign in with any real mobile number. In development no SMS is sent: the code appears on the code screen and in the API log.

Run without `API_URL` and the app works fully on the device (demo mode, code `123456`).

## How the pieces connect

| Flow | Path |
|---|---|
| Sign in | App → `POST /v1/auth/otp/request` → SMS (console in dev, Twilio in prod) → `POST /v1/auth/otp/verify` → access + refresh tokens (stored in the phone's Keychain/Keystore) |
| Data | Saved on the phone first, queued, then sent (`PUT /v1/meals/{id}`, `PATCH /v1/me`, …). Works offline; on sign-in and app start the app pulls `GET /v1/me/bootstrap`. |
| AI scan | App uploads the photo → `POST /v1/scan` → OpenAI vision model (or the mock scanner) → validated JSON. Free-scan limits are enforced by the server. |
| Describe a meal | Search → "Log with AI" → `POST /v1/ai/parse-meal`. Foods in the database keep their checked numbers; unknown foods are estimated by the AI, saved for admin review (Food database → AI estimates to review) and opened in the normal review screen. |
| What to eat next | Today screen → `POST /v1/ai/suggestions` with what's left of today's calories and macros, the user's goal and recent meals. Cached ~2 h per budget. |
| AI limits | Free users: `ai_daily_limit_free` (admin Settings, default 20/day) for descriptions + suggestions; Pro: 200/day. Every request shows in admin → AI usage. |
| Payments | Price picked from the customer's verified phone country, in local currency (`backend/app/services/pricing.py`). App → `POST /v1/payments/order` (server sets the price) → Razorpay Checkout → `POST /v1/payments/verify` (signature check) → Pro on. The webhook `/v1/webhooks/razorpay` covers the app closing mid-payment. |
| Admin | Next.js server → `/v1/admin/*` with a separate admin login. Users, Pro access, suspensions, foods, broadcasts and settings all reach the app. |

## Tests

| Part | Command | Covers |
|---|---|---|
| backend | `cd backend && .venv/Scripts/python -m pytest` | OTP, tokens, meals, scan limits, admin, isolation between users, OpenAI scanner, payments, text AI (48 tests) |
| app | `cd nutrilens && flutter test` | UI flows, nutrition maths, API client, sync queue |
| app ↔ live API | `NUTRILENS_E2E_API=http://localhost:8001 flutter test test/backend_e2e_test.dart` | Sign in, sync, scan, search and pull against the running backend |
| admin | `cd admin && npx tsc --noEmit && npm run lint && npm run build` | Types, lint, production build |

## Going to production

See `backend/README.md`. You'll need to:
- set real secrets
- choose `SMS_PROVIDER=twilio`
- choose `AI_PROVIDER=openai` and provide `OPENAI_API_KEY`
- add Razorpay keys and the webhook
