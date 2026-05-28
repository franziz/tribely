import 'package:equatable/equatable.dart';

/// The 6 support-ticket categories accepted by POST /support/tickets.
///
/// [wireValue] returns the exact string the backend expects.
enum SupportCategory {
  reportFollowup7d,
  accountSignin,
  eventOrHost,
  appBroken,
  feedback,
  other;

  /// Wire value sent to the backend (matches the API enum literals exactly).
  String get wireValue {
    switch (this) {
      case SupportCategory.reportFollowup7d:
        return 'reportFollowup7d';
      case SupportCategory.accountSignin:
        return 'accountSignin';
      case SupportCategory.eventOrHost:
        return 'eventOrHost';
      case SupportCategory.appBroken:
        return 'appBroken';
      case SupportCategory.feedback:
        return 'feedback';
      case SupportCategory.other:
        return 'other';
    }
  }
}

/// User-composed support ticket before submission.
///
/// Pure Dart — no Flutter, no Dio, no Riverpod imports.
class SupportTicketDraft extends Equatable {
  const SupportTicketDraft({
    required this.category,
    required this.message,
    this.reportId,
  });

  final SupportCategory category;

  /// Free-text message body from the user.
  final String message;

  /// Optional — pre-populated when the user opens the form from the
  /// post-report sheet (links the ticket to a specific moderation report).
  final String? reportId;

  @override
  List<Object?> get props => [category, message, reportId];
}
