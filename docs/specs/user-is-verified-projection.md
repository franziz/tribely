# User.isVerified projection contract

Owner: engineering-lead
Status: Authoritative for TRI-65, TRI-66, TRI-67
Spec source: TRI-86
Last updated: 2026-05-18
Binding inputs:
- PM brief, TRI-86 comment 02a1f77c-60ea-4b09-b15d-4c3b86693382
- CEO verdict, TRI-86 comment 145f3c2e-973a-4c23-aad0-28b293126aa8
- Prior CEO rulings 2026-05-13, 2026-05-14, 2026-05-15

## 1. Contract summary

`isVerified` is a non-nullable `boolean` field exposed on every API response that
semantically describes a user. It is derived at query time from a configurable
set of verification signals on the User aggregate. There is one truth function;
every projection that exposes the field reads through it.

`true` ⟺ every signal in the active launch signal set is currently active for
that user. `false` otherwise, including the case where any signal in the active
set is not yet implemented end-to-end.

## 2. Field shape on every projection

| Projection | Path | Field | Notes |
| --- | --- | --- | --- |
| `GET /users/:id` | top-level | `isVerified: boolean` | TRI-65 |
| `GET /users/me` | top-level | `isVerified: boolean` | TRI-65 (same shape) |
| `GET /events/:id` | `host.isVerified: boolean` | nested under `host` | TRI-66 |
| Future user-summary (pending/attending rows) | per-row `isVerified: boolean` | same field name | TRI-67, deferred |

Rules:
- **Field name is `isVerified`.** No alternative spellings on any projection.
- **Type is `boolean`, non-nullable.** Never `null`, never an enum, never absent.
- **Always present** on any response that semantically describes a user.
- **Transient backend failure resolves to `false`**, never field-absent and never `null`.

Zod shape addition for `userResponseSchema`
(`apps/api/src/features/users/presentation/http/schemas/user.schemas.ts`):

```ts
isVerified: z.boolean(),
```

Zod shape addition for `eventWithHostResponseSchema`
(`apps/api/src/features/events/presentation/http/schemas/event.schemas.ts`):

```ts
host: z.object({
  id: z.string(),
  displayName: z.string(),
  isVerified: z.boolean(),
}),
```

Mobile-side reference: `bool isVerified` (non-nullable) on the corresponding
Dart models. TRI-64's `VerifiedPill` widget already consumes this exact shape.

## 3. Truth function

```
isVerified(user, signalSet) =
  signalSet is non-empty
  AND every signalId in signalSet is a known signal
  AND every signalId in signalSet is active for user
```

If `signalSet` is empty, or contains an unknown signal ID, the function returns
`false`. (This is the 2026-05-14 gating rule: until the upstream flow is wired
end-to-end, return `false`.)

Active-signal predicates (per known signal ID):

| signalId | active iff |
| --- | --- |
| `email` | `user.emailVerifiedAt IS NOT NULL` |
| `phone` | `user.phoneVerifiedAt IS NOT NULL` |
| `selfie` | `user.selfieApprovedAt IS NOT NULL` |

The set of *known* signal IDs is a closed enum maintained alongside the
projection. Adding a fourth signal (e.g., `id-document`) requires (a) extending
the enum, (b) adding its predicate, (c) extending User persistence to read the
column. Removing one requires only removing it from the env var.

## 4. Launch signal set — configuration

The active signal set is configured via the `VERIFIED_SIGNAL_SET` environment
variable. Parsed at boot by the API's Zod env schema; invalid values fail at
startup.

| Setting | Value | When |
| --- | --- | --- |
| Production launch (default) | `email,phone,selfie` | Once TRI-15 (Done), TRI-16, TRI-23 are all shipped |
| Pre-launch (any of TRI-15/16/23 unshipped) | `email,phone,selfie` (unchanged) | Truth function naturally returns `false` for unimplemented signals (per gating rule) |
| CEO-pre-authorized fallback | `email,selfie` | If Twilio Trust Hub KYC slips beyond CEO-authorized window |
| Dev / test default | `email,phone,selfie` | Matches production shape |

Env schema additions to
`apps/api/src/core/config/env.ts`:

```ts
VERIFIED_SIGNAL_SET: z
  .string()
  .default('email,phone,selfie')
  .transform((s) => s.split(',').map((p) => p.trim()).filter(Boolean))
  .pipe(z.array(z.enum(['email', 'phone', 'selfie']))),
```

This validates at boot that every signal ID in the config is a *known* signal —
typo'd or removed-but-still-configured signal IDs cause a loud startup failure,
not silent `false` projections.

**Fallback flip procedure** (CEO escalation, post-launch decision):
1. CEO escalates fallback.
2. Ops updates `VERIFIED_SIGNAL_SET=email,selfie` in production env.
3. Rolling restart of the API.
4. The very next read on every projection returns the new computation.
5. No DB migration, no code edit, no SWE cycle.

No mid-flight invalidation work is needed because the projection is derived at
read time; there is no cached `isVerified` anywhere in the system.

## 5. Source-of-truth shape — derived, not denormalized

`isVerified` is computed at query time. There is no `User.isVerified` column in
the database. There is no denormalized projection table. There is no cached
projection.

Trade-off taken: cheap reads were not needed at v1 scale; cross-projection
consistency under signal revocation was the priority. Derived satisfies both.

Revisit denormalization (with appropriate domain event + consumer scaffolding)
only if (a) a future verified-users discovery filter scans large user sets, OR
(b) event-detail or profile-sheet p95 measurably regresses on the host
projection cost. Until then, denormalization is over-engineering.

## 6. Projection module — single owner of the truth function

File path:
`apps/api/src/features/users/application/projections/is-verified.projection.ts`

Exports:
- `type VerificationSignalId = 'email' | 'phone' | 'selfie';`
- `interface VerificationSignals { emailVerifiedAt: Date | null; phoneVerifiedAt: Date | null; selfieApprovedAt: Date | null; }`
- `computeIsVerified(signals: VerificationSignals, signalSet: VerificationSignalId[]): boolean`

Rules:
- The function is **pure** (no I/O, no env reads inside). The active signal set
  is passed in. The env var is read at composition root (DI container) and
  injected via the use cases that call this module.
- The function returns `false` if `signalSet` is empty.
- The function returns `false` if any signal in `signalSet` is not yet known to
  the predicate map (defensive against future drift — this should be statically
  impossible due to the env var enum, but the predicate guards anyway).
- This is the **only** place the truth function exists. No controller, no
  schema, no other use case computes it inline. Reviewer will reject duplicates.

Placement rationale: the projection lives under `users/application/projections/`
because verification is owned by the `users` bounded context (the underlying
signals — `emailVerifiedAt`, `phoneVerifiedAt`, `selfieApprovedAt` — are User
aggregate state). Other features import the projection module as a sibling
application service. This is the cross-feature `application/ports/` exception
codified in CLAUDE.md A11.

## 7. Cross-aggregate consistency — `EventHost.isVerified`

The event-detail use case (TRI-66) computes `host.isVerified` as follows:

1. Load host User row (already needed for `host.displayName`).
2. Select the three signal columns on the same row (one additional projection
   in the same Prisma `select`, zero new queries).
3. Pass `{ emailVerifiedAt, phoneVerifiedAt, selfieApprovedAt }` and the active
   signal set into `computeIsVerified`.
4. Return the boolean as `host.isVerified`.

No caching. No invalidation. No domain event. No consumer. No outbox.

Because the projection is derived at read time on the live User row, the
consistency property required by PM ("a user's `isVerified` and their
`host.isVerified` on any event they host cannot disagree at any moment a client
could observe both") is satisfied by construction: both projections read the
same three columns through the same module on the same Prisma query path.

## 8. Revocation path

Signal revocation (e.g., admin un-approves a selfie):
- The owning use case (selfie admin review on TRI-23) clears
  `user.selfieApprovedAt` (or transitions the underlying status field) inside
  its own transactional boundary.
- The very next query that reads `computeIsVerified` returns `false`.
- No additional infrastructure: nothing to invalidate, nothing to recompute,
  no event to publish (from the perspective of this projection — TRI-23's
  domain events for the selfie aggregate itself are out of this spec's scope).

Idempotency: the derived shape is naturally idempotent. A repeated revocation
(e.g., a duplicate admin action) sees the column already null and is a no-op.

## 9. Domain events — none introduced by this spec

This spec does NOT introduce:
- A `UserVerificationChanged` event.
- A `UserVerifiedSignalChanged` event.
- A consumer that reacts to signal flips.
- A new outbox interaction.

TRI-15/16/23 emit their own domain events for their own purposes (e.g.,
`UserEmailVerified`, future `UserPhoneVerified`, `UserSelfieApproved`). The
`isVerified` projection does NOT subscribe to them.

## 10. Test surface for TRI-65 / TRI-66 SWE

Tests SWE must include at the projection module + use case level:

1. **Truth-function unit tests** (pure):
   - Empty signal set → `false`
   - Signal set `['email']`, user `emailVerifiedAt` not null → `true`
   - Signal set `['email','phone','selfie']`, all three set → `true`
   - Signal set `['email','phone','selfie']`, one missing → `false`
   - Signal set `['email','selfie']`, both set, `phoneVerifiedAt` null → `true`
     (asserts fallback-set behavior)
   - Unknown signal ID in set → `false` (defensive)

2. **Integration tests** at HTTP layer (TRI-65):
   - `GET /users/:id` returns `isVerified: false` when any signal column is null
   - `GET /users/:id` returns `isVerified: true` when all configured signals
     active for that user
   - Field is **always present**, never `null`, never absent

3. **Integration tests** at HTTP layer (TRI-66):
   - `GET /events/:id` returns `host.isVerified: false` when host's required
     signals incomplete
   - `host.isVerified` agrees with `GET /users/:id` `isVerified` for the same
     user at the same moment

4. **Env config tests**:
   - Boot with `VERIFIED_SIGNAL_SET=email,selfie` parses to `['email', 'selfie']`
   - Boot with `VERIFIED_SIGNAL_SET=invalid` fails at startup
   - Boot with `VERIFIED_SIGNAL_SET=` (empty) parses to `[]` and every
     projection returns `false`

## 11. Migration plan

No DB migration is required by this spec.

TRI-16 (phone) and TRI-23 (selfie) will each ship their own migrations adding
`phoneVerifiedAt` / `selfieApprovedAt` (or equivalent status fields) to the
`users` table. This spec consumes those columns when they land; it does not
add them itself.

If selfie ships as a `selfieStatus` enum rather than a `selfieApprovedAt`
timestamp, the `selfie` signal predicate in the projection module changes from
`user.selfieApprovedAt !== null` to `user.selfieStatus === 'approved'`. The
external contract (`isVerified: boolean`) is unchanged.

## 12. Scaffolding flags for TRI-65/66 SWE

- No `/api-new-event` invocation.
- No `/api-new-consumer` invocation.
- No `/api-new-usecase` for the projection itself — it's a pure module, not a
  use case. Place it directly at `users/application/projections/`.
- TRI-65/66 may use `/api-new-usecase` for any new use case shape they need
  (e.g., `GetEventDetail` if not already present).

## 13. Out of scope

- Tiered verification (Bronze/Silver/Gold).
- "Missing signals" or "reasons" projection.
- Per-event-context verification scoping.
- Backfill of historical `isVerified` (every user is `false` until upstream).
- Admin UI for flipping signals.
- Generic verification framework abstraction beyond the closed signal-ID enum.
