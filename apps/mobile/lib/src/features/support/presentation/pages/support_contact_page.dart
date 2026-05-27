import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/tribely_text_field.dart';
import '../../domain/entities/support_ticket_draft.dart';
import '../controllers/support_contact_controller.dart';
import '../controllers/support_contact_state.dart';
import '../string_assets/support_copy.dart';
import '../widgets/category_selector_sheet.dart';

/// Full-screen support contact form.
///
/// Accepts an optional `reportId` deep-link query parameter. When present:
///   - Pre-selects [SupportCategory.reportFollowup7d].
///   - Pre-fills the Report ID field.
///   - Focuses the message field post-frame (so the keyboard appears).
///
/// Call-site example (from [GoRoute] builder — registered in M3):
/// ```dart
/// GoRoute(
///   path: '/support/contact',
///   builder: (context, state) => const SupportContactPage(),
/// )
/// ```
/// The page reads its own [GoRouterState] in [initState], so no constructor
/// args are needed; the deep-link params flow in via the URI.
class SupportContactPage extends ConsumerStatefulWidget {
  const SupportContactPage({super.key});

  @override
  ConsumerState<SupportContactPage> createState() => _SupportContactPageState();
}

class _SupportContactPageState extends ConsumerState<SupportContactPage> {
  // ---------------------------------------------------------------------------
  // Controllers and focus nodes
  // ---------------------------------------------------------------------------

  final _scrollController = ScrollController();
  final _messageController = TextEditingController();
  final _reportIdController = TextEditingController();
  final _messageFocusNode = FocusNode();

  SupportCategory? _selectedCategory;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onFormChanged);
    _reportIdController.addListener(_onFormChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleDeepLink());
  }

  void _handleDeepLink() {
    if (!mounted) return;
    final reportId = GoRouterState.of(context).uri.queryParameters['reportId'];
    if (reportId != null && reportId.isNotEmpty) {
      setState(() {
        _selectedCategory = SupportCategory.reportFollowup7d;
        _reportIdController.text = reportId;
      });
      // Focus the message field so the user can start typing immediately.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _messageFocusNode.requestFocus();
      });
    }
  }

  void _onFormChanged() => setState(() {});

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _reportIdController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Business logic
  // ---------------------------------------------------------------------------

  bool get _canSubmit =>
      _selectedCategory != null && _messageController.text.trim().isNotEmpty;

  Future<void> _onSubmit() async {
    if (!_canSubmit) return;

    final draft = SupportTicketDraft(
      category: _selectedCategory!,
      message: _messageController.text.trim(),
      reportId: _reportIdController.text.trim().isNotEmpty
          ? _reportIdController.text.trim()
          : null,
    );

    await ref.read(supportContactControllerProvider.notifier).submit(draft);

    if (!mounted) return;

    final state = ref.read(supportContactControllerProvider);
    if (state is SupportContactSuccess) {
      context.pushReplacement('/support/contact/success?id=${state.ticketId}');
    } else if (state is SupportContactError) {
      // Scroll to top so the error banner is visible.
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _openCategorySheet() async {
    final result = await showModalBottomSheet<SupportCategory?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => CategorySelectorSheet(initial: _selectedCategory),
    );
    if (result != null) {
      setState(() => _selectedCategory = result);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(supportContactControllerProvider);
    final isSubmitting = controllerState is SupportContactSubmitting;
    final errorMessage = controllerState is SupportContactError
        ? controllerState.message
        : null;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? TribelyColors.nightInkPrimary
        : TribelyColors.paperInkPrimary;
    final inkSecondary = dark
        ? TribelyColors.nightInkSecondary
        : TribelyColors.paperInkSecondary;
    final borderSubtle = dark
        ? TribelyColors.nightBorderSubtle
        : TribelyColors.paperBorderSubtle;

    return Scaffold(
      appBar: AppBar(
        title: Text(supportContactPageTitle, style: TribelyType.headline(ink)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -------------------------------------------------------
                    // Error banner — live region for a11y; dismissible.
                    // -------------------------------------------------------
                    if (errorMessage != null) ...[
                      Semantics(
                        liveRegion: true,
                        child: BannerMessage(
                          message: errorMessage,
                          onDismiss: () => ref
                              .read(supportContactControllerProvider.notifier)
                              .dismissBanner(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // -------------------------------------------------------
                    // Subject tap-target row — styled like TribelyTextField.
                    // -------------------------------------------------------
                    _SubjectRow(
                      selectedCategory: _selectedCategory,
                      ink: ink,
                      inkSecondary: inkSecondary,
                      borderSubtle: borderSubtle,
                      enabled: !isSubmitting,
                      onTap: isSubmitting ? null : _openCategorySheet,
                    ),
                    const SizedBox(height: 16),

                    // -------------------------------------------------------
                    // Message field.
                    // -------------------------------------------------------
                    Opacity(
                      opacity: isSubmitting ? 0.5 : 1.0,
                      child: TribelyTextField(
                        controller: _messageController,
                        label: supportMessageLabel,
                        helper: supportMessageCaption,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        minLines: 5,
                        maxLines: null,
                        enabled: !isSubmitting,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // -------------------------------------------------------
                    // Report ID field (single-line, italic caption).
                    // -------------------------------------------------------
                    Opacity(
                      opacity: isSubmitting ? 0.5 : 1.0,
                      child: TribelyTextField(
                        controller: _reportIdController,
                        label: supportReportIdLabel,
                        helper: supportReportIdCaption,
                        enabled: !isSubmitting,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // -------------------------------------------------------
                    // Privacy microcopy.
                    // -------------------------------------------------------
                    Text(
                      supportPrivacyMicrocopy,
                      style: TribelyType.caption(inkSecondary),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // -----------------------------------------------------------------
            // Sticky bottom — submit button + disabled hint.
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                children: [
                  if (!_canSubmit && !isSubmitting) ...[
                    Text(
                      supportSubmitDisabledHint,
                      style: TribelyType.caption(inkSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],
                  PrimaryButton(
                    label: supportSubmitCta,
                    onPressed: _canSubmit && !isSubmitting ? _onSubmit : null,
                    state: isSubmitting
                        ? PrimaryButtonState.loading
                        : PrimaryButtonState.idle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subject row widget — inlined per brief's non-goal (no shared widget).
// ---------------------------------------------------------------------------

/// Tap-target styled to match [TribelyTextField]:
///   - 12dp corner radius
///   - 1.5dp border in [borderSubtle]
///   - 56dp minimum height
///
/// Tapping opens [CategorySelectorSheet].
class _SubjectRow extends StatelessWidget {
  const _SubjectRow({
    required this.selectedCategory,
    required this.ink,
    required this.inkSecondary,
    required this.borderSubtle,
    required this.enabled,
    required this.onTap,
  });

  final SupportCategory? selectedCategory;
  final Color ink;
  final Color inkSecondary;
  final Color borderSubtle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasSelection = selectedCategory != null;
    final labelColor = hasSelection ? ink : inkSecondary;
    final label = hasSelection
        ? supportCategoryDisplayName(selectedCategory!)
        : supportSubjectPlaceholder;

    return Semantics(
      label: hasSelection ? 'Subject: $label' : 'Subject, tap to choose',
      button: true,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 56),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderSubtle, width: 1.5),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: TribelyType.bodyM(labelColor)),
                ),
                Icon(Icons.keyboard_arrow_down, size: 20, color: inkSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
