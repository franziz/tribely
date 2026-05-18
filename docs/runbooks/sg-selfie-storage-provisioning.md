# SG Selfie Storage — Provisioning Runbook

**Status:** v1.0
**Owner:** Repo owner (one-time setup)
**Linear:** TRI-77
**Last updated:** 2026-05-18

---

## 1. Purpose & scope

This runbook provisions the AWS S3 bucket for Singapore-resident selfie storage as specified in `docs/policies/selfie-retention.md` §5 and required by TRI-77. It is a one-time setup task performed by the repo owner. It assumes an AWS account already exists and that the AWS CLI is locally configured (`aws configure` or equivalent env vars). Running this runbook is a prerequisite for both TRI-5 (the `S3FileStorage` adapter) and TRI-23 (the selfie capture flow) to be production-usable.

---

## 2. Pre-requisites

- AWS account with billing alarms set.
- AWS CLI ≥ 2.x installed and authenticated (`aws sts get-caller-identity` returns cleanly).
- IAM admin permission sufficient to create S3 buckets, IAM users, and inline IAM policies.
- The `tribely-api-prod` IAM user and its access keys do NOT yet exist — this runbook creates them. If they exist, stop and reconcile manually before continuing.

---

## 3. Create the bucket with server-side encryption

Both commands are run back-to-back to ensure no upload window exists between bucket creation and encryption enforcement.

```bash
aws s3api create-bucket \
  --bucket tribely-selfies-prod-sg-ap-southeast-1 \
  --region ap-southeast-1 \
  --create-bucket-configuration LocationConstraint=ap-southeast-1
```

```bash
aws s3api put-bucket-encryption \
  --bucket tribely-selfies-prod-sg-ap-southeast-1 \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": false
    }]
  }'
```

**Why back-to-back:** the `create-bucket` call does not enable SSE atomically. Any upload issued between creation and the `put-bucket-encryption` call would land unencrypted. Running both immediately eliminates that window.

---

## 4. Apply Public Access Block

```bash
aws s3api put-public-access-block \
  --bucket tribely-selfies-prod-sg-ap-southeast-1 \
  --public-access-block-configuration '{
    "BlockPublicAcls": true,
    "IgnorePublicAcls": true,
    "BlockPublicPolicy": true,
    "RestrictPublicBuckets": true
  }'
```

**Why:** belt-and-suspenders against future bucket-policy or ACL changes that might inadvertently grant public read. The application never serves objects publicly — signed URLs are the only access path. Locking all four flags at the bucket level enforces this independently of any policy authored later.

---

## 5. Create IAM user, policy, and access keys

Create the application user:

```bash
aws iam create-user --user-name tribely-api-prod
```

Attach a minimal inline policy granting only the three operations the application needs:

```bash
aws iam put-user-policy \
  --user-name tribely-api-prod \
  --policy-name tribely-selfie-storage-v1 \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::tribely-selfies-prod-sg-ap-southeast-1/*"
    }]
  }'
```

Create the access key pair and capture the credentials:

```bash
aws iam create-access-key --user-name tribely-api-prod
```

The response includes `AccessKeyId` and `SecretAccessKey`. **Capture both values now** — the secret is shown only once. Store them in your password manager or secrets vault. Do NOT commit them anywhere.

**Why least privilege:** the application only needs to put, get, and delete objects inside this specific bucket. No `s3:ListBucket`, no bucket-level actions, no other AWS services. A compromised credential has the smallest possible blast radius.

---

## 6. Verify the bucket

Run the following checklist before configuring the application or declaring this bucket production-ready.

> **Pre-flight (one-time):** AWS account created. IAM user `tribely-api-prod` created with programmatic access. AWS CLI installed locally (`aws --version` works). The repo owner has the new access key ID + secret captured locally; they are NOT committed anywhere.

**Step 1 — Bucket exists in the correct region (AC2).**
- Action: `aws s3api get-bucket-location --bucket tribely-selfies-prod-sg-ap-southeast-1`
- Expected: `{"LocationConstraint": "ap-southeast-1"}`. Any other region → STOP, delete and recreate.

**Step 2 — Server-side encryption is enabled with AES-256 (AC3).**
- Action: `aws s3api get-bucket-encryption --bucket tribely-selfies-prod-sg-ap-southeast-1`
- Expected: includes `"SSEAlgorithm": "AES256"`. Absence → STOP, re-apply per §3.

**Step 3 — Public Access Block is fully enabled (AC4 setup).**
- Action: `aws s3api get-public-access-block --bucket tribely-selfies-prod-sg-ap-southeast-1`
- Expected: all four flags `true` (`BlockPublicAcls`, `IgnorePublicAcls`, `BlockPublicPolicy`, `RestrictPublicBuckets`). Any `false` → STOP, re-apply per §4.

**Step 4 — Upload a test object via authenticated CLI (AC5 setup).**
- Action: `echo "tribely-test-$(date +%s)" > /tmp/storage-smoke.txt && aws s3 cp /tmp/storage-smoke.txt s3://tribely-selfies-prod-sg-ap-southeast-1/_smoke/storage-smoke.txt`
- Expected: `upload: ...` with no errors.

**Step 5 — Anonymous GET returns 403 (AC4 enforcement).**
- Action: `curl -sS -o /dev/null -w "%{http_code}\n" "https://tribely-selfies-prod-sg-ap-southeast-1.s3.ap-southeast-1.amazonaws.com/_smoke/storage-smoke.txt"`
- Expected: prints `403`. A `200` → STOP IMMEDIATELY, bucket is publicly readable.

**Step 6 — Generate a signed URL and confirm read + expiry (AC5 end-to-end).**
- Action: `aws s3 presign s3://tribely-selfies-prod-sg-ap-southeast-1/_smoke/storage-smoke.txt --expires-in 60` — copy URL, then `curl -sS "<paste-url>"`.
- Expected: returns the file contents. Wait 65 seconds and re-curl: expected `<Error><Code>AccessDenied</Code>...`.

**Step 7 — Clean up smoke object.**
- Action: `aws s3 rm s3://tribely-selfies-prod-sg-ap-southeast-1/_smoke/storage-smoke.txt`
- Expected: `delete: ...` with no errors.

**Step 8 — Record completion in PR description.**
- Tick this checklist in the PR body. Note any deviations.

---

## 7. Configure `apps/api/.env` for production deploy

Add the following five env vars to the production environment (do NOT commit to `.env`):

```
STORAGE_TRANSPORT=s3
STORAGE_BUCKET=tribely-selfies-prod-sg-ap-southeast-1
STORAGE_REGION=ap-southeast-1
STORAGE_ACCESS_KEY_ID=<from step 5>
STORAGE_SECRET_ACCESS_KEY=<from step 5>
```

Two optional vars exist for provider-swap scenarios (see §10) and are unused for AWS S3:

```
# STORAGE_ENDPOINT=         # leave unset for native AWS S3
# STORAGE_FORCE_PATH_STYLE= # leave unset for native AWS S3
```

> **Warning:** Until TRI-5 lands, setting `STORAGE_TRANSPORT=s3` will crash boot with a message pointing at TRI-5. That is expected behaviour — the S3 adapter is not yet implemented. Do not set `STORAGE_TRANSPORT=s3` in production until TRI-5 is merged.

---

## 8. Rotation procedure

1. Create a new access key for `tribely-api-prod` via `aws iam create-access-key`.
2. Deploy the new `STORAGE_ACCESS_KEY_ID` + `STORAGE_SECRET_ACCESS_KEY` to the production environment.
3. Confirm application is healthy (no auth errors in logs).
4. Delete the old access key via `aws iam delete-access-key --access-key-id <old-id> --user-name tribely-api-prod`.

**Rotation cadence:** on personnel change or annually, whichever comes first — pre-launch. Post-launch cadence is at Legal & Compliance discretion.

---

## 9. Decommissioning / changing buckets

1. Provision the new bucket following §3–§5 of this runbook.
2. Update `STORAGE_BUCKET` (and creds if the user changed) in the production environment.
3. Decide on legacy objects: backfill to the new bucket, or accept loss of objects that pre-date the migration (per the retention windows in `docs/policies/selfie-retention.md` §7, most objects will have already been deleted by daily scheduled jobs).
4. Delete the old bucket only after you are satisfied no in-flight operations reference it and no outstanding retention obligations apply.

Do NOT repurpose buckets across environments (e.g., do not rename `prod` to `staging`). Provision a fresh bucket per environment.

---

## 10. Swapping to a different S3-compatible provider (e.g., R2, B2, MinIO)

> **JURISDICTIONAL WARNING — read before proceeding.**
> Swapping the storage provider is a PDPA review, not a config change. `STORAGE_ENDPOINT` makes any S3-compatible provider reachable, but directing data to a provider whose storage nodes are outside Singapore (Cloudflare R2 without a Singapore endpoint, Backblaze B2 in US/EU, MinIO on a non-SG host, GCS in US/EU, etc.) triggers PDPA s26 cross-border transfer obligations. That requires fresh legal sign-off before the configuration is deployed to production. The existence of the env var does not constitute pre-approval.

To execute the swap after legal sign-off:

1. Provision the bucket on the target provider, applying equivalent encryption and public-access controls per §3–§4 above.
2. Create equivalent IAM/API credentials with minimal scope (§5 pattern).
3. Set `STORAGE_ENDPOINT` to the provider's S3-compatible API URL.
4. Set `STORAGE_FORCE_PATH_STYLE=true` if the provider requires it (MinIO and some self-hosted setups do; R2, B2, and Wasabi do not).
5. Update `STORAGE_BUCKET`, `STORAGE_REGION`, `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`.
6. Re-run the entire verification checklist (§6) against the new provider before routing production traffic.

---

## 11. Follow-ups deferred (to be filed at TRI-77 closeout)

- **Backup-tier verification:** confirm backups containing deleted selfies are aged out within 30 days of the primary deletion trigger, per `docs/policies/selfie-retention.md` §8 "Backup propagation".
- **Scheduled-deletion cron + account-deletion cascade:** implement the daily deletion job and account-deletion cascade described in policy §7–§8. Currently unscheduled.
- **Reviewer access logging:** implement per-URL-signing-event audit log per policy §6 ("Every read of a selfie image... is logged"). Currently unimplemented.
- **Optional Terraform adoption post-launch:** consider codifying the bucket, BPA, encryption, and IAM resources in Terraform for repeatable infra. Deferred until post-launch; manual provisioning per this runbook is sufficient for v1.
