/**
 * Outbound port for transactional email. Lives in `core` because email is
 * a cross-cutting concern consumed by multiple bounded contexts (auth's
 * verification + password reset, check-in safety reports, future invites,
 * etc.) — not a property of any one feature.
 *
 * Implementations decide transport (logging stub for dev/test, Resend for
 * production). This is a primitive port: callers compose their own template
 * (subject, html, text) and call `send` directly. Template functions live
 * in `core/email/templates/` and are imported by feature use cases.
 *
 * The adapter does not know about email types or content — it owns only
 * delivery. This keeps bounded contexts responsible for their own messaging
 * copy and enables any feature to send email without modifying the port.
 */
export interface EmailSender {
  send(input: { to: string; subject: string; html: string; text: string }): Promise<void>;
}
