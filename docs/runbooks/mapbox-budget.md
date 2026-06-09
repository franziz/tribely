# Mapbox Budget — Manual Cap & Kill-Switch Runbook

**Status:** v1.0
**Provider:** Mapbox (Search Box API + Static Images API)
**Owner:** Repo owner (operational)
**On-call operator:** TODO — repo owner to assign a named operator
**Linear:** TRI-257 (this runbook); TRI-59 (downstream degraded-quota UX); TRI-265 (in-app counter follow-up)
**Last updated:** 2026-06-02

## §1 Purpose & scope

Mapbox does not support hard usage caps or USD-denominated alerts on its dashboard. The free tier is 50,000 calls/month per API. This runbook replaces an automated cap with a manual weekly Statistics-page check and a deletion-based kill switch, ensuring Tribely stops consuming Mapbox APIs at the free-tier boundary and degrades gracefully to the venue-name-manual-entry UX defined in TRI-59. **In scope:** weekly check procedure, three threshold-response definitions, token deletion (kill-switch), post-kill restoration roadmap. **Out of scope:** USD-denominated caps, automated alerting, paid-tier headroom, in-app call counting (see TRI-265).

## §2 Configured thresholds & responses

| Call count (monthly) | % of free tier | Operator response |
|---|---|---|
| 25,000 | 50% | Heightened cadence: switch weekly check to **daily**. Log each daily reading in §4 log table. |
| 40,000 | 80% | **Token rotation prep.** Provision a replacement token in Mapbox console (do NOT ship). Verify replacement token successfully completes one Search Box `/suggest` + one Static Images request via curl. Hold replacement in 1Password / secrets store, tagged `mapbox-prod-standby`. Do not delete the production token yet. |
| 50,000 | 100% (free-tier boundary) | **Immediate kill.** Execute §5 token deletion procedure. Confirm `VenuePickerDegradedQuota` banner appears in app (§6 verification). |

There is **no paid-tier headroom by design.** The 50,000 boundary is a hard cap. Decisions to raise it require re-running TRI-257's full product/EL/CEO workflow — see §8.

## §3 Where to read the call count (Mapbox Statistics page)

1. Open https://console.mapbox.com/account/statistics/ (operator must be logged in as a Mapbox account collaborator).
2. Set the date-range selector to **the current calendar month** (Mapbox bills per calendar month; quota resets at UTC midnight on the 1st).
3. Read **Search Box API → Requests** — record the integer count.
4. Read **Static Images API → Requests** — record the integer count separately.
5. The threshold in §2 applies to **the higher of the two readings** (the first API to cross the boundary triggers the response — they are quota-independent on Mapbox's side, but Tribely treats whichever crosses first as the trigger to maintain symmetry with downstream UX).

## §4 Weekly check procedure + log

1. On a fixed weekday (operator's choice; suggest Monday morning SGT), open the Statistics page per §3.
2. Record both readings in the log table below as a new row.
3. Apply the threshold-response table in §2 based on the higher reading.
4. If the reading crossed a threshold since the last check, take the §2 response immediately — do not wait for the next check.
5. If a calendar-month boundary has passed since the last check, expect both readings to have reset to near-zero; the new month's quota begins fresh.

| Date (YYYY-MM-DD) | Search Box requests | Static Images requests | Higher reading % of free tier | Action taken | Operator |
|---|---|---|---|---|---|
| 2026-06-XX | — | — | — | First reading post-merge | TODO |
| 2026-06-XX | — | — | — | — | TODO |

(Operator appends rows in-place to the runbook on each check. The runbook IS the audit log, per AC.)

## §5 Token deletion procedure (the kill switch)

> **Target execution time: ≤15 minutes from decision to in-app effect.** This budget covers Mapbox console deletion + propagation. It does NOT include restoring service (see §7).

1. Confirm the replacement token from the 40k-threshold prep step (§2 row 2) exists in standby. If it does not, the operator is in an unprepared kill — log this as an incident in §4 and proceed; service restoration will take longer.
2. Open https://console.mapbox.com/account/access-tokens/.
3. Identify the production token (the one currently embedded in shipped app binaries — see §5.1 for how to identify).
4. Click **Delete** on the production token. Confirm the destructive-action prompt.
5. Within ~1–2 minutes, Mapbox revokes the token server-side. Existing app binaries calling `api.mapbox.com/search/searchbox/v1/*` and `api.mapbox.com/styles/v1/*/static/*` will receive HTTP 401 or 403.
6. The mobile data layer (`mapbox_place_search_remote_datasource.dart`) maps 401/403/429 → `QuotaExhaustedException` → `PlaceSearchRepository` `QuotaFailure` → `VenuePickerDegradedQuota` state (see §6 and TRI-59).
7. Verify per §6.

#### §5.1 How to identify the production token

The production token is the value passed via `--dart-define=MAPBOX_ACCESS_TOKEN=pk.xxx` at app build time. To identify which Mapbox console token corresponds to the currently-shipped builds:

- **If the build pipeline location is known:** read the secret from there. **TODO — repo owner: document actual release pipeline location** (e.g., Codemagic environment group `prod-mobile`, GitHub Actions secret `MAPBOX_ACCESS_TOKEN`, local `fastlane` `.env`, etc.). Until this TODO is resolved, identification is by Mapbox-console-side metadata only.
- **Mapbox-console-side identification:** the production token's note/name should be `tribely-prod-mobile` (operator to set this at first provisioning, per §9). Inspect token scopes — production has `styles:tiles`, `styles:read`, `fonts:read`, `search:*` scopes and is public (`pk.` prefix).

## §6 Downstream UX cross-reference

Post-kill, the mobile app's venue-picker enters the `VenuePickerDegradedQuota` state defined in TRI-59. The user sees the venue-picker autocomplete disabled and the following locked banner copy (do NOT change — TRI-59 reviewer-locked):

> **Search is temporarily unavailable. Enter the venue name manually below.**

The manual-entry text field becomes the venue-name source. Static map previews on event-detail and event-creation summary screens degrade to a non-map placeholder per TRI-59's downstream rendering rules. The 401/403 from Mapbox is treated identically to the 429 quota response — both map to `QuotaFailure` in the data layer.

## §7 Post-kill restoration roadmap (not a 15-minute step)

Restoring Mapbox-backed venue search requires shipping a new mobile app build with the standby token (or a freshly-provisioned token) embedded via `--dart-define=MAPBOX_ACCESS_TOKEN`. Because the token is compile-time bound, this is bounded by app-store review latency (typically 1–3 days for iOS / hours for Android), NOT by the 15-minute kill budget.

Restoration steps:

1. Confirm the standby token from §2 row 2 is valid (curl test against `/suggest`).
2. **TODO — repo owner: document the release pipeline.** Update the production secret in [PIPELINE_LOCATION_TODO] with the standby token value.
3. Cut a new mobile build via the standard release procedure.
4. Submit to TestFlight + Play Console; promote to production after review.
5. On user app-update, venue search resumes. Users on older app versions remain in degraded state until they update.

**Implication:** the kill switch is a one-way door inside any single calendar month. The operator should only execute §5 when the new calendar month is reasonably close, OR when overage cost is a higher concern than UX degradation. If the calendar month resets within 24–48 hours of crossing 50k, simply executing §5 and letting quota reset is the simplest path.

## §8 Escalation / out-of-scope

- **Do NOT raise the Mapbox plan to paid tier without re-running the TRI-257 workflow** (PM + CEO + EL). The 50k hard cap is a deliberate stage-appropriate decision for Singapore launch.
- **Do NOT add a Tribely-side in-app call counter** as a side-quest. That work is tracked in TRI-265 — file there, do not inline here.
- **Do NOT rely on Mapbox's automatic "free-tier-crossed" email** for the 25k or 40k thresholds. Mapbox auto-emails ONCE per billing period at first crossing; it is informational, not the primary signal.
- If during a weekly check the operator finds quota already crossed 50k without having executed §5, treat as an incident: execute §5 immediately, then log the gap in §4 with `Action taken = unprepared kill, lag = N days`.

## §9 First-time provisioning checklist (one-time)

Repo owner executes this once after merging TRI-257:

- [ ] Production token exists in Mapbox console, named `tribely-prod-mobile`, with scopes `styles:tiles, styles:read, fonts:read, search:*`.
- [ ] Production token value is recorded in [PIPELINE_LOCATION_TODO] and embedded in the latest shipped app build.
- [ ] Standby token slot in 1Password / secrets store is created (empty until 40k threshold).
- [ ] Statistics page (https://console.mapbox.com/account/statistics/) is reachable when logged in as the operator's Mapbox account.
- [ ] §4 log table contains an initial row with the current month's reading.
- [ ] On-call operator name is filled in at the top of this runbook (replacing the TODO).
- [ ] Operator has dry-run-walked §5 mentally (no actual deletion).
