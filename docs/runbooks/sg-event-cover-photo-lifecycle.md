# SG Event Cover Photos — S3 Lifecycle Orphan Sweep

**Status:** v1.0
**Owner:** Repo owner (one-time setup + ongoing verification)
**Linear:** TRI-304
**Last updated:** 2026-06-26

---

## 1. Purpose & scope

This runbook configures an S3 lifecycle rule that expires abandoned cover-photo
objects under the `events/<hostUserId>/` prefix. It is a follow-up to TRI-49,
which shipped the event cover-photo upload flow without a synchronous
orphan-deletion path.

The rule targets objects that were uploaded to S3 but **never attached to a
published event** — for example, a host who opens the create-event flow, uploads a
cover photo, then abandons the draft. The API fuses the `coverPhotoStorageKey`
into the `Event` aggregate only on `POST /events` (or `PUT /events/:id/cover-photo`
for an existing event). Until that confirm step runs, the object is an orphan.

**This runbook is owner-executed.** Agents do not have AWS credentials. Apply the
commands in this document against the real AWS account out-of-band. The PR that
ships this runbook contains only documentation.

---

## 2. Why a lifecycle rule (not a real-time delete)

- The create-event draft state lives entirely on the mobile client today; the
  server has no durable "draft" record to hook a delete into.
- An S3 lifecycle rule is sufficient for v1: orphans are not user-visible and the
  volume is bounded by host upload frequency.
- Real-time orphan deletion on draft-discard is explicitly a non-goal of
  TRI-304.

---

## 3. Selection decision

| Decision | Selected value | Rationale |
|---|---|---|
| Prefix | `events/` | All cover-photo objects are stored under `events/<hostUserId>/<imageId>.<ext>` (`request-cover-photo-upload.usecase.ts`). |
| Action | `Expiration` with `Days: 7` | Seven days is longer than the 5-minute presigned-URL window and longer than any legitimate draft-to-publish interval, but short enough to prevent unbounded accumulation. It is intentionally conservative: a host who publishes within seven days is unaffected because the object is referenced by a live `Event` row and will typically be read via signed URL before expiry. |
| Scope | Whole `events/` prefix | The ownership sub-prefix (`events/<hostUserId>/`) is enforced at creation/replacement time by the use case; the lifecycle rule does not need per-host granularity. |
| Noncurrent versions | Not configured | Versioning is not enabled on this bucket by default. If versioning is enabled later, add a separate `NoncurrentVersionExpiration` rule. |
| Incomplete multipart uploads | Not configured | Cover photos are single PUTs via presigned URL; multipart abort cleanup is unnecessary for this prefix. |
| Tags / filters | None beyond prefix | Keeps the rule simple and auditable. |

**Important:** The seven-day window is **not a retention commitment** to users.
It is an internal storage-hygiene setting. Published-event cover photos are
referenced by DB rows and are expected to be read (and therefore retained) well
within the seven-day window. If a future feature intentionally leaves a cover
photo unreferenced for longer than seven days, that feature must either (a)
confirm the key within seven days, or (b) file a ticket to revisit this rule.

---

## 4. Pre-requisites

- AWS CLI ≥ 2.x installed and authenticated with admin or S3-lifecycle privileges.
- The bucket `tribely-selfies-prod-sg-ap-southeast-1` already exists and was
  provisioned per `docs/runbooks/sg-selfie-storage-provisioning.md`.
- You understand that this rule applies to the **same shared bucket** used for
  selfies and avatars. The prefix guard (`events/`) prevents the rule from
  touching `avatars/` or `uploads/` objects.

---

## 5. Apply the lifecycle rule

Create a local file `/tmp/tribely-events-cover-photo-lifecycle.json`:

```json
{
  "Rules": [
    {
      "ID": "tribely-expire-orphaned-event-cover-photos",
      "Status": "Enabled",
      "Filter": {
        "Prefix": "events/"
      },
      "Expiration": {
        "Days": 7
      }
    }
  ]
}
```

Then apply it:

```bash
aws s3api put-bucket-lifecycle-configuration \
  --bucket tribely-selfies-prod-sg-ap-southeast-1 \
  --lifecycle-configuration file:///tmp/tribely-events-cover-photo-lifecycle.json
```

**Why `put-bucket-lifecycle-configuration` replaces the whole configuration:**
S3 lifecycle rules are set at the bucket level as a single document. If the
bucket already has other lifecycle rules, merge this rule into the existing JSON
before calling `put-bucket-lifecycle-configuration`, or the existing rules will
be removed.

---

## 6. Verify the rule

### 6.1 Read back the configuration

```bash
aws s3api get-bucket-lifecycle-configuration \
  --bucket tribely-selfies-prod-sg-ap-southeast-1
```

Expected output includes exactly the rule above:

```json
{
  "Rules": [
    {
      "ID": "tribely-expire-orphaned-event-cover-photos",
      "Status": "Enabled",
      "Filter": { "Prefix": "events/" },
      "Expiration": { "Days": 7 }
    }
  ]
}
```

### 6.2 Confirm no rule touches `avatars/` or `uploads/`

Inspect the returned JSON. Every rule must either:
- have a non-overlapping prefix, or
- overlap intentionally and be documented.

The TRI-304 rule is the only rule permitted to touch `events/`.

### 6.3 Smoke test with a temporary object

```bash
# Create a test object under the events/ prefix
echo "orphan-smoke-$(date +%s)" > /tmp/cover-smoke.txt
aws s3 cp /tmp/cover-smoke.txt \
  s3://tribely-selfies-prod-sg-ap-southeast-1/events/_smoke/lifecycle-smoke.txt

# Confirm it is reachable via signed URL
aws s3 presign \
  s3://tribely-selfies-prod-sg-ap-southeast-1/events/_smoke/lifecycle-smoke.txt \
  --expires-in 60
# (curl the URL — should return the file contents)

# Check S3 reports an expiry date. Note: S3 computes expiry at midnight UTC
# after the object is at least 7 days old, so the reported date may be ~8 days
# from creation depending on upload time.
aws s3api head-object \
  --bucket tribely-selfies-prod-sg-ap-southeast-1 \
  --key events/_smoke/lifecycle-smoke.txt
```

Look for the `Expiration` response header in the `head-object` output. It may not
appear immediately; S3 lifecycle processing is eventually consistent. Re-check
after a few hours if absent.

**Clean up the smoke object once you have confirmed the header appears, or
let the lifecycle rule delete it naturally.**

---

## 7. Operational checks

### "Are orphaned cover photos accumulating?"

S3 does not provide a native metric for "orphan" objects. Use the following
proxy checks:

1. **Object count under `events/`** (CloudWatch or S3 Storage Lens):
   ```bash
   aws s3 ls s3://tribely-selfies-prod-sg-ap-southeast-1/events/ --recursive --summarize
   ```
   Compare the object count against the number of live events with
   `coverPhotoStorageKey` set. A large, growing gap indicates orphans.

2. **Lifecycle rule metrics** (if enabled in S3 Storage Lens):
   Look for `TransitionedObjectCount` / `ExpiredObjectCount` under the
   `events/` prefix after the rule has been active for 7+ days.

### "Did the rule accidentally delete a referenced cover photo?"

This should not happen if the rule is left at 7 days, because referenced cover
photos are read via signed URL by event participants well before expiry. If a
reported 404 on a cover photo appears:

1. Check the object's `Expiration` header timestamp.
2. Check the `Event.coverPhotoStorageKey` and `updatedAt` to see if the event was
   created/replaced more than 7 days after upload.
3. If the gap is real, extend the rule's `Days` value and file a follow-up.

---

## 8. Rollback

To disable the rule without deleting it:

```bash
aws s3api get-bucket-lifecycle-configuration \
  --bucket tribely-selfies-prod-sg-ap-southeast-1 \
  > /tmp/tribely-lifecycle-backup.json

# Edit /tmp/tribely-lifecycle-backup.json, set Status to Disabled for the rule

aws s3api put-bucket-lifecycle-configuration \
  --bucket tribely-selfies-prod-sg-ap-southeast-1 \
  --lifecycle-configuration file:///tmp/tribely-lifecycle-backup.json
```

To remove the rule entirely, use the same read-edit-write flow and delete the
rule object from the JSON before `put-bucket-lifecycle-configuration`.

---

## 9. Follow-ups deferred

- **Real-time orphan deletion on draft discard:** non-goal for v1. Revisit if
  storage volume or cost becomes material.
- **Terraform / IaC adoption:** see TRI-114.
- **Separate event-cover-photo bucket:** not required while the shared bucket
  uses prefix-level lifecycle rules. Revisit if the events prefix needs
  materially different access controls or retention.
