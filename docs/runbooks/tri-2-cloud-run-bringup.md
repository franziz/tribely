# TRI-2 — Production Cloud Run Bringup Runbook

Audience: operator with GCP project admin, Neon org admin, and `gotribely.com` DNS access.
This document is self-sufficient — no other file is required to execute a full production bringup.

---

## Preconditions checklist

Before starting, confirm every item below.

### Tools (local machine)

- [ ] `gcloud` CLI installed and authenticated (`gcloud auth login && gcloud auth application-default login`)
- [ ] Active GCP project set: `gcloud config set project <YOUR_GCP_PROJECT_ID>`
- [ ] `curl` available
- [ ] `dig` available (macOS: built-in; Linux: `apt install dnsutils`)
- [ ] Browser access to the Neon dashboard (https://console.neon.tech)
- [ ] Admin access to `gotribely.com` DNS at your registrar/DNS provider

### Accounts and resources

- [ ] GCP project with billing enabled, region `asia-southeast1` (Singapore) selected
- [ ] Cloud Run API enabled: `gcloud services enable run.googleapis.com cloudbuild.googleapis.com secretmanager.googleapis.com`
- [ ] Neon project in region `aws-ap-southeast-1` (Singapore) — the default branch is production
- [ ] Control of `gotribely.com` DNS (registrar admin panel)
- [ ] Resend account with `gotribely.com` DKIM verified, API key ready
- [ ] Twilio account with a Verify Service created, account SID + auth token + service SID ready
- [ ] AWS IAM user (or S3-compatible provider) with access key + secret for the selfie storage bucket

### Repository

- [ ] Local clone of the repo on branch `chore/TRI-2-prod-deploy-bringup` (or main after merge)
- [ ] `cd` to the **repo root** for all `gcloud` commands in this runbook (not `apps/api/`)

---

## Step 1 — Generate production secrets

> **Never echo secrets into your shell — they appear in shell history and terminal scrollback.**
> Use `printf '%s'` piped directly to `gcloud secrets create` as shown below.

### 1a. JWT_SECRET

```bash
printf '%s' "$(openssl rand -hex 32)" | \
  gcloud secrets create JWT_SECRET \
    --replication-policy automatic \
    --data-file=-
```

### 1b. PHONE_HASH_SALT

```bash
printf '%s' "$(openssl rand -hex 32)" | \
  gcloud secrets create PHONE_HASH_SALT \
    --replication-policy automatic \
    --data-file=-
```

**Success signal:** both secrets appear in the list.

```bash
gcloud secrets list --filter="name:(JWT_SECRET PHONE_HASH_SALT)"
```

Expected output: two rows, `CREATED` timestamps within the last minute.

---

## Step 2 — Retrieve Neon production DATABASE_URL

1. Open the Neon dashboard → your project → **default branch** → **Connection Details**.
2. Select **Direct connection** (NOT pooled). The Prisma `@prisma/adapter-pg` driver manages its own connection pool and requires the direct URL.
3. The connection string looks like: `postgresql://user:pass@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require`

Store it as a GCP secret — do NOT paste into a shell variable:

```bash
printf '%s' "postgresql://user:pass@ep-xxxx.ap-southeast-1.aws.neon.tech/neondb?sslmode=require" | \
  gcloud secrets create DATABASE_URL \
    --replication-policy automatic \
    --data-file=-
```

Replace the connection string with the one copied from the Neon dashboard.

**Success signal:**

```bash
gcloud secrets versions list DATABASE_URL
```

Expected output: one row with state `ENABLED` and version `1`.

---

## Step 3 — Create remaining production secrets

Run each block separately. Replace placeholder values with real credentials.

### RESEND_API_KEY

```bash
printf '%s' "re_xxxxxxxxxxxxxxxxxxxx" | \
  gcloud secrets create RESEND_API_KEY \
    --replication-policy automatic \
    --data-file=-
```

### TWILIO_ACCOUNT_SID

```bash
printf '%s' "ACxxxxxxxxxxxxxxxxxxxx" | \
  gcloud secrets create TWILIO_ACCOUNT_SID \
    --replication-policy automatic \
    --data-file=-
```

### TWILIO_AUTH_TOKEN

```bash
printf '%s' "your-twilio-auth-token" | \
  gcloud secrets create TWILIO_AUTH_TOKEN \
    --replication-policy automatic \
    --data-file=-
```

### TWILIO_VERIFY_SERVICE_SID

```bash
printf '%s' "VAxxxxxxxxxxxxxxxxxxxx" | \
  gcloud secrets create TWILIO_VERIFY_SERVICE_SID \
    --replication-policy automatic \
    --data-file=-
```

### STORAGE_ACCESS_KEY_ID

```bash
printf '%s' "your-storage-access-key-id" | \
  gcloud secrets create STORAGE_ACCESS_KEY_ID \
    --replication-policy automatic \
    --data-file=-
```

### STORAGE_SECRET_ACCESS_KEY

```bash
printf '%s' "your-storage-secret-access-key" | \
  gcloud secrets create STORAGE_SECRET_ACCESS_KEY \
    --replication-policy automatic \
    --data-file=-
```

**Success signal:** all eight secrets visible.

```bash
gcloud secrets list
```

Expected names: `JWT_SECRET`, `PHONE_HASH_SALT`, `DATABASE_URL`, `RESEND_API_KEY`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_VERIFY_SERVICE_SID`, `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`.

---

## Step 4 — First Cloud Run deploy

> **Working directory: REPO ROOT** (where `Dockerfile` and `.dockerignore` live).
> The build context spans the entire workspace — do NOT `cd apps/api` first.

### Grant Cloud Run the Secret Manager accessor role

The service account that runs the Cloud Run revision must be able to read the secrets.
The default Compute service account is used here; substitute if you created a dedicated SA.

```bash
PROJECT_ID=$(gcloud config get-value project)
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)')

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${PROJECT_NUMBER}-compute@developer.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

### Deploy

Run from **repo root**:

```bash
gcloud run deploy tribely-api \
  --source . \
  --region asia-southeast1 \
  --platform managed \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 5 \
  --cpu 1 \
  --memory 512Mi \
  --port 3000 \
  --timeout 60s \
  --startup-cpu-boost \
  --set-env-vars "NODE_ENV=production,\
PORT=3000,\
LOG_LEVEL=info,\
EMAIL_TRANSPORT=resend,\
EMAIL_FROM=Tribely <noreply@gotribely.com>,\
APP_BASE_URL=https://api.gotribely.com,\
SMS_TRANSPORT=twilio,\
SMS_ALLOWED_COUNTRY_CODES=+65,\
STORAGE_TRANSPORT=s3,\
STORAGE_BUCKET=your-production-bucket-name,\
STORAGE_REGION=ap-southeast-1,\
VERIFIED_SIGNAL_SET=email\,phone\,selfie,\
SAFETY_REPORT_EMAIL=safety@gotribely.com" \
  --set-secrets "DATABASE_URL=DATABASE_URL:latest,\
JWT_SECRET=JWT_SECRET:latest,\
PHONE_HASH_SALT=PHONE_HASH_SALT:latest,\
RESEND_API_KEY=RESEND_API_KEY:latest,\
TWILIO_ACCOUNT_SID=TWILIO_ACCOUNT_SID:latest,\
TWILIO_AUTH_TOKEN=TWILIO_AUTH_TOKEN:latest,\
TWILIO_VERIFY_SERVICE_SID=TWILIO_VERIFY_SERVICE_SID:latest,\
STORAGE_ACCESS_KEY_ID=STORAGE_ACCESS_KEY_ID:latest,\
STORAGE_SECRET_ACCESS_KEY=STORAGE_SECRET_ACCESS_KEY:latest"
```

**Before running:** replace `your-production-bucket-name` with the real S3/R2 bucket name from the storage provisioning runbook (`sg-selfie-storage-provisioning.md`).

Cloud Build will upload the repo root as the build context, run the multi-stage Dockerfile, push the image to Artifact Registry, and deploy the revision. This takes approximately 3–5 minutes.

**Success signal:** deploy prints a `*.run.app` service URL. Verify:

```bash
SERVICE_URL=$(gcloud run services describe tribely-api --region asia-southeast1 --format='value(status.url)')
curl "${SERVICE_URL}/health"
```

Expected response: `{"status":"ok"}` with HTTP 200.

### Fallback: if `--source .` fails on Cloud Build upload

If the `--source .` upload times out or fails, build and push the image manually first:

```bash
# From repo root
gcloud builds submit --tag "gcr.io/${PROJECT_ID}/tribely-api" .

gcloud run deploy tribely-api \
  --image "gcr.io/${PROJECT_ID}/tribely-api" \
  --region asia-southeast1 \
  --platform managed \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 5 \
  --cpu 1 \
  --memory 512Mi \
  --port 3000 \
  --timeout 60s \
  --startup-cpu-boost \
  --set-env-vars "..." \
  --set-secrets "..."
```

Carry over the same `--set-env-vars` and `--set-secrets` flags from the primary deploy command above.

### env.ts cross-reference — all production-required vars

The table below maps every var in `apps/api/src/core/config/env.ts` to where it appears in this deploy.
"Secret" = injected via `--set-secrets`; "Env" = `--set-env-vars`; "Default" = no override needed.

| Variable | How set | Notes |
|---|---|---|
| `NODE_ENV` | Env (`production`) | Enables production guards |
| `PORT` | Env (`3000`) | Cloud Run injects its own PORT at runtime; match Dockerfile EXPOSE |
| `LOG_LEVEL` | Env (`info`) | Default is `info`; override to `warn` to reduce log volume later |
| `DATABASE_URL` | Secret | Direct (non-pooled) Neon connection string |
| `JWT_SECRET` | Secret | Min 32 chars; never reuse across environments |
| `JWT_ACCESS_TTL` | Default (`15m`) | Override via Env if you need a different TTL |
| `JWT_REFRESH_TTL` | Default (`30d`) | Override via Env if needed |
| `EMAIL_VERIFICATION_TTL` | Default (`48h`) | Override via Env if needed |
| `PASSWORD_RESET_TTL` | Default (`24h`) | Override via Env if needed |
| `EMAIL_TRANSPORT` | Env (`resend`) | Required non-`log` in production (superRefine enforces) |
| `RESEND_API_KEY` | Secret | Required when `EMAIL_TRANSPORT=resend` |
| `EMAIL_FROM` | Env | Must override default `onboarding@resend.dev`; use `gotribely.com` verified sender |
| `APP_BASE_URL` | Env | Must override default `http://localhost:3000` |
| `VERIFIED_SIGNAL_SET` | Env (`email,phone,selfie`) | Default is `email,phone,selfie`; explicit here for clarity |
| `SMS_TRANSPORT` | Env (`twilio`) | Required non-`log` in production (superRefine enforces) |
| `TWILIO_ACCOUNT_SID` | Secret | Required when `SMS_TRANSPORT=twilio` |
| `TWILIO_AUTH_TOKEN` | Secret | Required when `SMS_TRANSPORT=twilio` |
| `TWILIO_VERIFY_SERVICE_SID` | Secret | Required when `SMS_TRANSPORT=twilio` |
| `SMS_ALLOWED_COUNTRY_CODES` | Env (`+65`) | Singapore-only launch default; add markets by changing this var |
| `STORAGE_TRANSPORT` | Env (`s3`) | Required non-`log` in production (superRefine enforces) |
| `STORAGE_BUCKET` | Env | Required when `STORAGE_TRANSPORT=s3` |
| `STORAGE_REGION` | Env | Required when `STORAGE_TRANSPORT=s3`; `ap-southeast-1` for Singapore |
| `STORAGE_ACCESS_KEY_ID` | Secret | Required when `STORAGE_TRANSPORT=s3` |
| `STORAGE_SECRET_ACCESS_KEY` | Secret | Required when `STORAGE_TRANSPORT=s3` |
| `STORAGE_ENDPOINT` | Not set | Omit for AWS S3; set for R2/MinIO/Wasabi |
| `STORAGE_FORCE_PATH_STYLE` | Not set | Default `false`; set `true` for MinIO |
| `STORAGE_READ_URL_MAX_SECONDS` | Not set | Default 3600 (1h); tighten via Env if needed |
| `STORAGE_UPLOAD_URL_MAX_SECONDS` | Not set | Default 300 (5m); tighten via Env if needed |
| `PHONE_HASH_SALT` | Secret | Min 32 chars; required in production (superRefine enforces) |
| `SAFETY_REPORT_EMAIL` | Env (`safety@gotribely.com`) | Default is already `safety@gotribely.com`; explicit here for clarity |
| `SELFIE_DELETION_SWEEP_INTERVAL_MS` | Default (86400000) | 24h; override via Env if needed |
| `SELFIE_RETENTION_SWEEP_INTERVAL_MS` | Default (86400000) | 24h; override via Env if needed |
| `POST_EVENT_CHECK_IN_SWEEP_INTERVAL_MS` | Default (86400000) | 24h; override via Env if needed |
| `POST_EVENT_CHECK_IN_AUDIT_SWEEP_INTERVAL_MS` | Default (86400000) | 24h; override via Env if needed |

---

## Step 5 — First `prisma migrate deploy` against Neon production

> **WARNING: This writes to the production database. Run only after confirming the DATABASE_URL below targets the Neon default branch (production). There is no undo — migration rollback requires a forward fix-migration.**

Retrieve the production connection string from GCP Secret Manager (avoid re-typing it):

```bash
PROD_DB_URL=$(gcloud secrets versions access latest --secret=DATABASE_URL)
```

Run migrations from the `apps/api/` directory (where `prisma/` and `package.json` live):

```bash
cd /path/to/repo/apps/api
DATABASE_URL="$PROD_DB_URL" npm run db:migrate:deploy
```

**Success signal:** Prisma prints:

```
All migrations have been successfully applied.
```

If any migration fails, Prisma will print the migration name and SQL error. Do not re-run until the failure is understood — a partial migration leaves the schema in an intermediate state.

**Reference for migration rollback:** https://www.prisma.io/docs/orm/prisma-migrate/workflows/patching-and-hotfixing

---

## Step 6 — Custom domain mapping

### Create the domain mapping

```bash
gcloud beta run domain-mappings create \
  --service tribely-api \
  --domain api.gotribely.com \
  --region asia-southeast1
```

The command returns the DNS records to create. It will look similar to:

```
NAME                 RECORD TYPE  CONTENTS
api.gotribely.com    CNAME        ghs.googlehosted.com.
```

### Add DNS records at your registrar

Log in to your DNS provider's admin panel and create the CNAME record returned by the command above:

| Host/Name | Type  | Value                   | TTL  |
|-----------|-------|-------------------------|------|
| `api`     | CNAME | `ghs.googlehosted.com.` | 3600 |

### Verify DNS propagation

```bash
dig api.gotribely.com CNAME +short
```

Expected: `ghs.googlehosted.com.`

DNS propagation typically takes 5–15 minutes. Google-managed TLS provisioning begins automatically once DNS resolves and takes a further 10–15 minutes.

**Success signal:** (after ~15 minutes total)

```bash
curl https://api.gotribely.com/health
```

Expected: `{"status":"ok"}` with HTTP 200, served over a valid certificate (no TLS warning).

---

## Step 7 — GitHub Actions secrets (BEFORE the next PR that touches `apps/api/prisma/**`)

The CI workflow creates an ephemeral Neon branch for each PR that modifies the Prisma schema. Without these secrets the `neon-branch` check fails and blocks the PR.

### Create the Neon API key

1. Open the Neon dashboard → your organization settings (top-left org menu) → **API keys**.
2. Click **Create new API key**.
3. Name: `github-actions-ephemeral-branches`
4. Scope: Organization (allows branch creation across all projects).
5. Copy the key — it is shown once only.

### Retrieve the Neon project ID

In the Neon dashboard URL when viewing your project:
`https://console.neon.tech/app/projects/<PROJECT_ID>`

Or from the project settings page (Settings → General → Project ID).

### Add secrets to GitHub

GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.

| Secret name       | Value                                          |
|-------------------|------------------------------------------------|
| `NEON_API_KEY`    | The API key generated above                    |
| `NEON_PROJECT_ID` | The Neon project ID (not the branch ID)        |

**Success signal:** Open a no-op PR that modifies a comment in `apps/api/prisma/schema.prisma`. The `neon-branch` check in GitHub Actions turns green within approximately 2 minutes.

---

## Step 8 — End-to-end smoke

Run both checks from a **non-corporate network** (mobile hotspot or public WiFi) to validate that the service is publicly reachable and not accidentally locked to a GCP internal network.

### Health check

```bash
curl -v https://api.gotribely.com/health
```

Expected:
- HTTP 200
- Body: `{"status":"ok"}`
- TLS certificate valid for `api.gotribely.com`, issued by Google Trust Services

### 404 error shape

```bash
curl -v https://api.gotribely.com/nonexistent-route-12345
```

Expected:
- HTTP 404
- Body is JSON (validates Hono's `onError` middleware is loaded), similar to: `{"message":"Not Found"}`
- NOT an HTML error page from a proxy or CDN

---

## Vendor-neutrality reminders

> This deployment targets Cloud Run + Neon. **No Google Cloud SDKs are imported in source code** (verify: `grep -r '@google-cloud' apps/api/src` → empty output). Secrets are vanilla env vars injected via `--set-secrets` (no Secret Manager volume mounts, no GCP-flavored SDK reads). To port to Fly.io: `fly secrets set` per secret, `fly.toml` mirrors the env list, `fly deploy` uses the same Dockerfile. To port to a different Postgres provider: change `DATABASE_URL` only. **Any Neon→other-provider swap OR `ap-southeast-1`→non-ASEAN region change is a PDPA legal re-review trigger** — `legal-compliance` must rule before the swap merges. Vendor-neutral code shape does NOT bypass the data-residency review.

---

## Rollback procedure

If a bad revision reaches production, redirect all traffic to the last known-good revision without touching the database.

### List recent revisions

```bash
gcloud run revisions list --service tribely-api --region asia-southeast1
```

Note the `REVISION` name of the last known-good revision (e.g., `tribely-api-00003-xyz`).

### Redirect traffic

```bash
gcloud run services update-traffic tribely-api \
  --to-revisions tribely-api-00003-xyz=100 \
  --region asia-southeast1
```

**Important:** rollback does NOT roll back the database. If the bad revision included a migration, the DB schema is already changed. Use a forward fix-migration to restore the expected schema state. See: https://www.prisma.io/docs/orm/prisma-migrate/workflows/patching-and-hotfixing

---

## Cost-tuning toggles

### Eliminate cold starts (operator discretion)

Cold starts on Cloud Run add 1–3 seconds to the first request after a period of inactivity. If this is unacceptable, set `--min-instances=1` to keep one warm instance at all times.

Estimated cost: ~$10–15 USD/month for one always-warm `1 vCPU / 512 Mi` instance in `asia-southeast1`.

```bash
gcloud run services update tribely-api \
  --min-instances 1 \
  --region asia-southeast1
```

### Scale ceiling for traffic growth

The current ceiling is 5 instances. If traffic grows and p99 latency climbs under load, raise it:

```bash
gcloud run services update tribely-api \
  --max-instances 20 \
  --region asia-southeast1
```

Estimated cost: each additional concurrent instance adds the equivalent of ~$10–15 USD/month when fully warm. At 20 max instances the ceiling cost is approximately $200–300 USD/month if all instances stay warm simultaneously (unlikely unless traffic is truly sustained). Serverless pricing applies — you pay per request-second, not per idle instance above the min floor.

---

## Technical non-goals

The following are explicitly deferred. Do not add them during initial bringup.

- **No HA / multi-region.** `asia-southeast1` (Singapore) only. Multi-region is a post-launch ops decision.
- **No Cloud Logging / Trace / Tasks / Pub-Sub / Scheduler SDKs.** The service uses `pino` for structured stdout logs; Cloud Run captures these automatically. No SDK integration required.
- **No image registry push from CI.** Cloud Build handles image building and pushing internally during `--source` deploy. CI does not push to Artifact Registry.
- **No staging environment.** The first deploy IS production. Tighten the deploy command and run smoke tests before executing Step 4.
- **No CDN, no Cloud Armor, no IAP.** Add these post-launch when traffic patterns are understood.
- **No prod Neon branch.** The Neon default branch is production. Branching strategy is deferred to launch-readiness hardening.
