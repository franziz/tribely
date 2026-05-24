# TRI-2 — Production image build & push

**Status:** active
**Owner:** repo owner (manual execution)
**Scope:** Build the API container image and push to Docker Hub. Runtime deployment (VPS, orchestrator, reverse proxy, TLS, env injection) is the repo owner's manual concern and is intentionally out of scope for this runbook. Tracked separately in TRI-183.

## What this runbook does NOT cover

- VPS provisioning, SSH access, systemd units, or container orchestration on the host
- Database migrations against the production Neon branch (run separately via `npm run --workspace=@tribely/api db:migrate:deploy` once the image is live, or as a one-shot from a workstation)
- DNS, TLS, reverse proxy, or domain mapping
- Secrets injection at runtime — the image ships with no embedded secrets; the runtime host supplies `DATABASE_URL`, `JWT_SECRET`, etc. via env

## Prerequisites (one-time, on the build machine)

1. **Docker Desktop or Docker Engine with buildx** — `docker buildx version` must succeed.
   - macOS/Windows: Docker Desktop includes buildx.
   - Linux: `docker buildx install` or install the `docker-buildx-plugin` package.

2. **A buildx builder that supports multi-arch.** Create once:
   ```bash
   docker buildx create --name tribely --driver docker-container --use
   docker buildx inspect --bootstrap
   ```
   Confirm `Platforms:` includes `linux/amd64` and `linux/arm64`.

3. **Docker Hub login** as the `franziz` account:
   ```bash
   docker login
   # Username: franziz
   # Password: <access token from https://hub.docker.com/settings/security>
   ```
   Use a personal access token, not the account password.

4. **CLI tools on PATH:** `yq` (v4+), `jq`, `curl`. `tools/build.sh` checks these via `require_tools_for_config` and `require_tools_for_hub` and exits with a clear message if any are missing.

## Build & push

From the repo root:

```bash
bash tools/build.sh
```

You will be prompted for:

1. **Build type** — free text (e.g., `prd`, `uat`, `dev`). Becomes the tag prefix.
2. **Next build number** — the script queries Docker Hub for tags matching `<build_type>.<n>` and suggests the next integer. Press Enter to accept the suggestion, or type a different number.

Non-interactive shortcut (build type as first arg, accept suggested number):

```bash
bash tools/build.sh prd </dev/null
```

The script then runs:

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t franziz/tribely-api:<build_type>.<n> \
  -f Dockerfile \
  --push \
  .
```

Buildx builds both architectures, pushes a manifest list to Docker Hub, and you are done. The final stdout line prints the pushed tag.

## Verifying the push

```bash
docker buildx imagetools inspect franziz/tribely-api:<build_type>.<n>
```

You should see entries for both `linux/amd64` and `linux/arm64`.

Or check the Docker Hub UI: https://hub.docker.com/r/franziz/tribely-api/tags

## Configuration

`tools/config.yml` holds image name, target platforms, build context, and Dockerfile path. The script also accepts:

- `CONFIG_FILE=/path/to/other.yml bash tools/build.sh` — use an alternate config
- `TAG_SEP=- bash tools/build.sh` — use `-` instead of `.` between build type and number (default: `.`)

Per-env build args may be added to `tools/config.yml` under `env.<build_type>.build_args:` — they are forwarded as `--build-arg KEY=VALUE`. None are currently used (the Dockerfile takes no build args).

## Troubleshooting

- **`docker buildx: command not found`** — buildx not installed or not on PATH. See prereq 1.
- **`ERROR: Multiple platforms feature is currently not supported for docker driver`** — your current builder is the default `docker` driver. Create the `docker-container` driver builder (prereq 2).
- **`unauthorized: authentication required` on push** — not logged in to Docker Hub as `franziz`, or the access token lacks write permission. Re-run `docker login`.
- **`yq: command not found` or `jq: command not found`** — install via Homebrew (macOS: `brew install yq jq`) or your distro's package manager.
- **Suggested number is `1` when you expect higher** — Docker Hub's tag listing API is paginated; the helper walks all pages. If you recently deleted tags, the suggestion reflects the surviving max + 1.

## What the image contains

Multi-stage build from `node:22-alpine`:

- Stage 1 (builder): `npm ci` for the full workspace, `prisma generate`, `tsc` to `apps/api/dist/`
- Stage 1b (deps): `npm ci --omit=dev` for a lean production `node_modules`, with the builder's `@prisma/client` + `.prisma/` overlaid
- Stage 2 (runtime): production `node_modules` + `apps/api/dist/` + `apps/api/prisma/`, runs as the `node` user, `CMD ["node", "apps/api/dist/index.js"]`

No secrets baked in. Host injects env at runtime.
