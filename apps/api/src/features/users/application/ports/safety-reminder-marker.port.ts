/**
 * Structural port that any caller (use case, stub, fake) can satisfy.
 * The real implementation is `MarkSafetyReminderSeenUseCase`. TypeScript
 * structural typing means concrete callers don't need `implements`.
 *
 * Layer placement note: this is an application-layer abstraction over
 * a use case ("another feature's application service"), not a domain
 * port over infrastructure. Domain ports describe outbound dependencies
 * the domain needs (Clock, Mailer); this describes "structural shape
 * of a sibling use case." That is why it lives in `application/ports/`,
 * not `domain/ports/`.
 */
export interface SafetyReminderMarkerPort {
  execute(input: { userId: string; eventId: string }): Promise<void>;
}
