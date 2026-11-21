# Deploying NutriLens

One Linux server runs everything with Docker: PostgreSQL, the API, the admin
panel, and Caddy (free HTTPS certificates, renewed automatically).

```
Internet ──443──▶ Caddy ──▶ api.<domain>   → API (FastAPI) ──▶ PostgreSQL
                        └─▶ admin.<domain> → Admin (Next.js)
```

## 1. Get a server and a domain
- A VPS with **Ubuntu 24.04, 2 GB RAM** or more (DigitalOcean, AWS Lightsail,
  Hetzner, Hostinger…). For Indian users pick a Mumbai/Bangalore region.
- In your domain's DNS add two **A records** pointing at the server's IP:
  `api.yourdomain.com` and `admin.yourdomain.com`.

## 2. Install Docker on the server
```bash
ssh root@YOUR_SERVER_IP
curl -fsSL https://get.docker.com | sh
ufw allow OpenSSH && ufw allow 80 && ufw allow 443 && ufw --force enable
```

## 3. Get the code
```bash
git clone https://github.com/dataverseanalytics/Mobile-app.git nutrilens
cd nutrilens/deploy
```
(Private repo: create a GitHub personal access token and use it as the password.)

## 4. Fill in the settings
```bash
cp .env.example .env               # domains + database password
cp backend.env.example backend.env # secrets: JWT, admin login, APITxT, OpenAI, Razorpay
nano .env
nano backend.env
```
Generate each secret/password with:
```bash
python3 -c "import secrets; print(secrets.token_urlsafe(48))"
```
The API refuses to start with development secrets or the default admin password.

## 5. Start
```bash
docker compose up -d --build
docker compose exec api python -m app.seed   # first time only: admin account + starter foods
```
Check: `https://api.yourdomain.com/v1/config` returns JSON, and
`https://admin.yourdomain.com` shows the login page.

## 6. Point the app at the server
```bash
cd nutrilens   # the Flutter project, on your PC
flutter build appbundle --release --dart-define=API_URL=https://api.yourdomain.com
```
Upload `build/app/outputs/bundle/release/app-release.aab` to Google Play Console.
(Set up release signing first — see Flutter's "Build and release an Android app".)

## 7. Razorpay webhook
Razorpay Dashboard → Webhooks → URL `https://api.yourdomain.com/v1/webhooks/razorpay`,
events `payment.captured`, `order.paid`, `payment.failed`; put the secret in
`backend.env` as `RAZORPAY_WEBHOOK_SECRET`, then `docker compose up -d`.

## Everyday commands (run in `deploy/`)
| Task | Command |
|---|---|
| Deploy new code | `git pull && docker compose up -d --build` (migrations run automatically) |
| Logs | `docker compose logs -f api` |
| Restart after editing `backend.env` | `docker compose up -d` |
| Database backup | `docker compose exec db pg_dump -U nutrilens nutrilens > backup-$(date +%F).sql` |
| Restore a backup | `docker compose exec -T db psql -U nutrilens nutrilens < backup.sql` |

Back up the database regularly (e.g. a daily cron job copying the dump off the server).
