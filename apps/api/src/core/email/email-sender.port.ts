/**
 * Outbound port for transactional email. Lives in `core` because email is
 * a cross-cutting concern consumed by multiple bounded contexts (auth's
 * verification + password reset, future event invites, etc.) — not a
 * property of any one feature.
 *
 * Implementations decide transport (logging stub for dev/test, Resend for
 * production). URLs are constructed by callers (use cases own their route
 * shape) and passed in — the adapter does not know about HTTP routes.
 *
 * Refactor trigger: when a third email type lands (welcome, magic link,
 * invite), promote this to a primitive `send({ to, subject, html, text })`
 * method and let feature-owned senders compose templates on top.
 */
export interface EmailSender {
  sendVerification(input: { to: string; verifyUrl: string }): Promise<void>;
  sendPasswordReset(input: { to: string; resetUrl: string }): Promise<void>;
}
