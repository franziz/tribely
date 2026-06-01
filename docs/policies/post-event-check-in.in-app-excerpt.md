# Post-Event Check-In — In-App Consent Excerpt

> Canonical source for the in-app intro sheet text shown at first foreground-trigger surface (TRI-29). Wire verbatim into the mobile string asset slot when TRI-29 ships. See [post-event-check-in.md](./post-event-check-in.md) for the full policy.
> The `%POLICY_URL%` token must be substituted with the public policy URL at build/wire time. Do not ship the literal token in the string asset.
> Surface A (safety-report hard gate) is TRI-238; canonical strings live in apps/mobile/lib/src/features/check_ins/presentation/string_assets/check_in_copy.dart.

---

After an event ends, Tribely will show you a one-time check-in prompt — just a quick "All good" or "I need help" so we know everyone got home safely.

If you tap "I need help," you can share a brief note. We collect the event details, the optional note, and the time of your response. Depending on the type, we keep these records for 30 days to 12 months — and deleting your account removes your records immediately.

If you raise a concern, we aim to review safety reports during Singapore business hours (Monday to Friday, 9am to 9pm SGT, excluding public holidays). The check-in is always voluntary; not responding simply means no record is created.

**If you're in immediate danger, call the Singapore Police at 999. We are not an emergency service.**

Your response is covered by our Privacy Policy (updated to include check-in data). Read the full policy: %POLICY_URL%
