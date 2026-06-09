# Neon CI Branch Backlog — One-Time Cleanup Runbook

**Status:** v1.0
**Owner:** Repo owner (one-time execution)
**Linear:** TRI-268
**Last updated:** 2026-06-03

---

## 1. Purpose & scope

This is a **one-time** runbook to clear the backlog of leaked `ci-pr-*` Neon branches that accumulated before the automated lifecycle mechanisms were in place.

**Ongoing prevention (do not use this runbook for routine cleanup):**
- `neon-cleanup.yml` — event-triggered; deletes the `ci-pr-<N>` branch immediately when a PR closes.
- `neon-reaper.yml` — scheduled daily at 03:00 UTC; sweeps any `ci-pr-*` branch older than 24 hours as a safety net.

After executing this runbook once, the above two workflows handle all future lifecycle. You should not need this runbook again unless there is a prolonged outage of both mechanisms.

---

## 2. Pre-requisites

- `NEON_API_KEY` — a Neon personal access token or project-scoped API key with permission to list and delete branches in the target project. This is the same key stored in the `NEON_API_KEY` GitHub Actions secret.
- `NEON_PROJECT_ID` — the Neon project ID (also stored as the `NEON_PROJECT_ID` GitHub Actions secret).
- `curl` and `jq` installed locally (`jq --version` and `curl --version` should return cleanly).
- If you prefer a UI: branches can alternatively be deleted individually via the **Neon Console → your project → Branches**, selecting each `ci-pr-*` branch and clicking Delete. The CLI approach below deletes them all in one pass and is faster for a large backlog.

---

## 3. Export credentials

```bash
export NEON_API_KEY="<your-neon-api-key>"
export NEON_PROJECT_ID="<your-neon-project-id>"
```

Verify the credentials resolve correctly:

```bash
curl -s \
  -H "Authorization: Bearer ${NEON_API_KEY}" \
  -H "Accept: application/json" \
  "https://console.neon.tech/api/v2/projects/${NEON_PROJECT_ID}" \
  | jq '.project.name'
```

Expected: prints your Neon project name as a quoted string. A `401` or `403` means the key is wrong or lacks permission — stop and verify before proceeding.

---

## 4. Inspect the backlog

List all current `ci-pr-*` branches so you can eyeball the backlog before deleting anything:

```bash
curl -s \
  -H "Authorization: Bearer ${NEON_API_KEY}" \
  -H "Accept: application/json" \
  "https://console.neon.tech/api/v2/projects/${NEON_PROJECT_ID}/branches" \
  | jq '[.branches[] | select(.name | startswith("ci-pr-")) | {name, id, created_at}]'
```

Expected output: a JSON array of objects, each with `name` (`ci-pr-<N>`), `id` (`br-...`), and `created_at` (ISO-8601 timestamp). An empty array `[]` means the backlog is already clear.

---

## 5. Dry run — print branch IDs that would be deleted

Run this before the live deletion to confirm the selection is correct. This only prints; it does not call DELETE.

```bash
curl -s \
  -H "Authorization: Bearer ${NEON_API_KEY}" \
  -H "Accept: application/json" \
  "https://console.neon.tech/api/v2/projects/${NEON_PROJECT_ID}/branches" \
  | jq -r '.branches[] | select(.name | startswith("ci-pr-")) | "\(.name)  \(.id)"'
```

Expected: one line per `ci-pr-*` branch, showing the human-readable name and the `br-...` id that will be passed to the DELETE call.

Only `ci-pr-*` names are matched. The Neon default branch and any branch whose name does not start with `ci-pr-` are never selected.

---

## 6. Live deletion

When the dry-run output looks correct, run the deletion loop:

```bash
curl -s \
  -H "Authorization: Bearer ${NEON_API_KEY}" \
  -H "Accept: application/json" \
  "https://console.neon.tech/api/v2/projects/${NEON_PROJECT_ID}/branches" \
  | jq -r '.branches[] | select(.name | startswith("ci-pr-")) | "\(.name) \(.id)"' \
  | while IFS=' ' read -r branch_name branch_id; do
      echo "Deleting ${branch_name} (${branch_id}) ..."
      http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X DELETE \
        -H "Authorization: Bearer ${NEON_API_KEY}" \
        -H "Accept: application/json" \
        "https://console.neon.tech/api/v2/projects/${NEON_PROJECT_ID}/branches/${branch_id}")
      echo "  HTTP ${http_code}"
    done
```

HTTP `200` or `204` per branch is success. `404` on an individual branch means it was already deleted (safe to ignore). Any `401`/`403` means the credential is wrong — stop and verify.

---

## 7. Verify the backlog is clear

Re-run the inspect query from §4. Expected: empty array `[]`.

```bash
curl -s \
  -H "Authorization: Bearer ${NEON_API_KEY}" \
  -H "Accept: application/json" \
  "https://console.neon.tech/api/v2/projects/${NEON_PROJECT_ID}/branches" \
  | jq '[.branches[] | select(.name | startswith("ci-pr-")) | {name, id, created_at}]'
```

---

## 8. Safety notes

- **Only `ci-pr-*` branches are targeted.** The `select(.name | startswith("ci-pr-"))` filter is the sole selection criterion. The Neon default branch (typically named `main` or `br-...` without the `ci-pr-` prefix) and any other non-`ci-pr-` branches are never touched.
- **This runbook is for the initial backlog only.** Ongoing lifecycle is fully automated — see `neon-cleanup.yml` (close-time deletion) and `neon-reaper.yml` (daily 03:00 UTC sweep).
- **No credentials are committed here.** Export them in your shell session only. Do not paste them into any file in this repo.
