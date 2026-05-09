import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/motion.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/widgets/banner_message.dart';
import '../../../../core/widgets/grain_overlay.dart';
import '../../../../core/widgets/ink_mark.dart';
import '../../../../core/widgets/primary_button.dart';
import '../providers/auth_providers.dart';
import '../state/auth_state.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage>
    with SingleTickerProviderStateMixin {
  static const _heroAsset = AssetImage('assets/images/welcome-hero.webp');
  late final AnimationController _parallax;
  bool _imagePrecached = false;

  @override
  void initState() {
    super.initState();
    _parallax = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-decode the hero image so the first paint doesn't stutter mid-animation.
    if (!_imagePrecached) {
      _imagePrecached = true;
      precacheImage(_heroAsset, context).catchError((_) {
        // Asset missing — Hero falls back to ink-mark block. Not an error.
      });
    }
  }

  @override
  void dispose() {
    _parallax.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        dark ? TribelyColors.nightSurface : TribelyColors.paperSurface;
    final ink =
        dark ? TribelyColors.nightInkPrimary : TribelyColors.paperInkPrimary;
    final inkSecondary =
        dark ? TribelyColors.nightInkSecondary : TribelyColors.paperInkSecondary;
    final accent =
        dark ? TribelyColors.nightAccent : TribelyColors.paperAccent;

    final session = ref.watch(sessionControllerProvider);
    final reason =
        session is SessionUnauthenticated ? session.reason : null;

    return Scaffold(
      backgroundColor: surface,
      body: Stack(
        children: [
          Column(
            children: [
              // 40% photo, 60% content — content gets enough room for the
              // headline + body + CTA stack on small phones (iPhone SE etc).
              Expanded(flex: 4, child: _Hero(parallax: _parallax)),

              Expanded(
                flex: 6,
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Scroll-if-needed pattern: IntrinsicHeight inside a
                      // ConstrainedBox(minHeight) lets Spacer pin CTAs to the
                      // bottom on tall screens AND lets content scroll on
                      // short screens. No RenderFlex overflow either way.
                      return SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(28, 24, 28, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (reason != null) ...[
                                    BannerMessage(
                                      message: reason,
                                      onDismiss: () => ref
                                          .read(sessionControllerProvider
                                              .notifier)
                                          .dismissReason(),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  const SizedBox(height: 4),
                                  _AnimatedHeadline(
                                    'Find your people, anywhere.',
                                    style: TribelyType.displayL(ink),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    "Solo travelers create real-life events. You join the ones that sound like you.",
                                    style: TribelyType.bodyL(inkSecondary),
                                  ),
                                  const Spacer(),
                                  PrimaryButton(
                                    label: 'Create an account',
                                    onPressed: () => context.go('/sign-up'),
                                  ),
                                  const SizedBox(height: 8),
                                  Center(
                                    child: TextButton(
                                      onPressed: () => context.go('/sign-in'),
                                      child: Text(
                                        'I already have one',
                                        style: TribelyType.bodyM(accent)
                                            .copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          GrainOverlay(opacity: dark ? 0.04 : 0.03),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.parallax});
  final AnimationController parallax;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        dark ? TribelyColors.nightPrimary : TribelyColors.paperAccent;

    // RepaintBoundary isolates the parallax layer — the slow continuous
    // translate doesn't invalidate the rest of the screen each frame.
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedBuilder(
              animation: parallax,
              builder: (_, __) {
                // Sine ease (not the default linear .value) — eliminates the
                // snap at the reverse turn-around point.
                final t = parallax.value;
                final smooth = 0.5 - 0.5 * (Curves.easeInOutSine.transform(t));
                final dy = (smooth - 0.5) * 16; // ±8dp drift
                return Transform.translate(
                  offset: Offset(0, dy),
                  child: Image.asset(
                    'assets/images/welcome-hero.webp',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _Fallback(),
                    // Decode at a fixed pixel height to avoid re-decoding on
                    // resize and to cap memory. cacheHeight is on
                    // Image.asset, not on the generic Image() constructor.
                    cacheHeight: 1500,
                    filterQuality: FilterQuality.low,
                  ),
                );
              },
            ),
            // Static gradient — no animation cost.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.55, 1.0],
                  colors: [
                    Colors.transparent,
                    accent.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark
        ? TribelyColors.nightSurfaceHigh
        : TribelyColors.paperSurfaceHigh;
    final ink =
        dark ? TribelyColors.nightInkPrimary : TribelyColors.paperInkPrimary;
    return Container(
      color: surface,
      child: Center(child: InkMark(size: 120, color: ink, animate: false)),
    );
  }
}

/// Stagger-fades each word of [text] using ONE [AnimationController] with
/// [Interval]s — much cheaper than the previous "one controller per word"
/// approach (which registered N tickers for the same animation).
class _AnimatedHeadline extends StatefulWidget {
  const _AnimatedHeadline(this.text, {required this.style});
  final String text;
  final TextStyle style;

  @override
  State<_AnimatedHeadline> createState() => _AnimatedHeadlineState();
}

class _AnimatedHeadlineState extends State<_AnimatedHeadline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<String> _words;
  static const _perWordOffset = 0.18; // fraction of total duration per word
  static const _perWordSpan = 0.55;

  @override
  void initState() {
    super.initState();
    _words = widget.text.split(' ');
    final totalMs = (350 + 200 * (_words.length - 1)).clamp(350, 1500);
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (context.reduceMotion) {
      return Text(widget.text, style: widget.style);
    }
    return Wrap(
      children: List.generate(_words.length, (i) {
        final start = (i * _perWordOffset).clamp(0.0, 1.0);
        final end = (start + _perWordSpan).clamp(0.0, 1.0);
        final animation = CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        );
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(animation),
              child: Text(_words[i], style: widget.style),
            ),
          ),
        );
      }),
    );
  }
}
