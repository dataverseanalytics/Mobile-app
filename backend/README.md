# NutriLens API

FastAPI · SQLAlchemy 2 (async) · PostgreSQL · Alembic · pytest.

## Develop

```bash
docker compose up -d db                  # PostgreSQL 17 on localhost:5434
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt
.venv/Scripts/alembic upgrade head
.venv/Scripts/python -m app.seed         # owner admin + starter food database
.venv/Scripts/uvicorn app.main:app --port 8001 --reload
.venv/Scripts/python -m pytest           # uses SQLite, no database needed
```

The Compose project is named `nutrilens`, so it won't clash with other projects whose folder is also called `backend`.

To change the database schema, edit `app/models.py`, then run:

```bash
alembic revision --autogenerate -m "describe change"
alembic upgrade head
```

## Layout

| Path | What |
|---|---|
| `app/routers/auth.py` | Phone OTP: request, verify, refresh (rotating), logout |
| `app/routers/app_api.py` | App endpoints: me, bootstrap, meals, weights, notices, foods, scan |
| `app/routers/payments.py` | Razorpay: plans, create order, verify signature, payment history, webhook |
| `app/services/pricing.py` | Prices per country/currency (edit `TIERS` to change prices) |
| `app/routers/admin.py` | Admin: login, stats, users, meals, foods, broadcasts, scan logs, config, team |
| `app/routers/ai.py` | Text AI: `POST /v1/ai/parse-meal` (describe a meal in words) and `POST /v1/ai/suggestions` (what to eat next). Daily limits, caching, usage logged |
| `app/services/ai.py` | Text AI provider: `mock` or `openai` (`OPENAI_TEXT_MODEL`). Foods it doesn't know are saved as unreviewed AI estimates for the admin to check |
| `app/services/scanner.py` | AI scanning: `mock` or `openai` (OpenAI vision model, structured output via the Responses API) |
| `app/services/sms.py` | OTP delivery: `console` (dev), `apitxt` (APITxT `/api/sendOTP`) or `twilio` |
| `app/models.py` | Schema (portable types; JSONB on PostgreSQL) |

## Security built in

| Area | Protection |
|---|---|
| OTP codes | Stored hashed, single-use, expire after 5 minutes, max 5 attempts, max 5 requests per hour, 30 s resend cooldown |
| Phone numbers | Validated for every country (libphonenumber); landlines rejected |
| Tokens | Access tokens last 30 min; refresh tokens last 60 days, rotate on each use and can be revoked. Admin tokens use a separate secret, so app tokens never work on the admin API. |
| Account status | Suspended users are blocked on their next request |
| Data access | Every query is limited to the signed-in user |
| Production start-up | The server refuses to start with the development secrets or the default admin password |

## Production checklist

| Setting | Value |
|---|---|
| `ENV` | `production` (also disables `/docs` and the demo upgrade endpoint) |
| `JWT_SECRET`, `ADMIN_JWT_SECRET` | 48+ random characters each |
| `ADMIN_EMAIL`, `ADMIN_PASSWORD` | Run `python -m app.seed` once to create the owner |
| `DATABASE_URL` | Managed PostgreSQL |
| `SMS_PROVIDER=apitxt` | Plus `APITXT_AUTH_KEY` (apitxt.com → API Keys). For India set `APITXT_TEMPLATE_ID` to your DLT-approved template; `APITXT_CHANNEL` can be `sms`, `whatsapp` or `voice` |
| or `SMS_PROVIDER=twilio` | Plus `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID` (Messaging Service SID) |
| `AI_PROVIDER=openai` | Plus `OPENAI_API_KEY`. `OPENAI_MODEL` (photo scans) defaults to `gpt-5.5`, `OPENAI_TEXT_MODEL` (meal descriptions, suggestions) to `gpt-5.4-mini`; set `OPENAI_REASONING_EFFORT` (e.g. `low`) for reasoning models. `SCAN_PROVIDER` still works as an alias |
| `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET` | Live keys from the Razorpay dashboard. Enable automatic capture of payments (Account & Settings → Payment capture) |
| International Payments | Enable in the Razorpay dashboard to charge USD/EUR/GBP/AED/SGD/AUD/CAD (cards only outside India) |
| `RAZORPAY_WEBHOOK_SECRET` | Webhook to `/v1/webhooks/razorpay` with events `payment.captured`, `order.paid`, `payment.failed` |
| `CORS_ORIGINS` | The admin panel's URL |
| `OTP_TEST_NUMBERS` | App Store review numbers only (they always accept `OTP_TEST_CODE`) |

Deploy with the `Dockerfile`. It runs migrations, then starts the server on port 8000.
