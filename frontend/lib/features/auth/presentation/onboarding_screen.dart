import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/storage/app_secure_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../main.dart';

/// Warm, journal-like onboarding carousel.
///
/// Four full-screen pages under a handwritten "AnyNote" wordmark header.
/// Headlines use the Caveat handwriting voice, page 1 shows a sticky-note
/// mascot built from widgets, and navigation is a purple circular next
/// button with page dots on the left. Page 3 features a live encryption demo.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  int _currentPage = 0;
  static const _totalPages = 4;

  // Demo animation state for page 3 (index 2)
  bool _demoActive = false;
  int _demoCharIndex = 0;
  bool _demoLockVisible = false;
  bool _demoSyncVisible = false;
  Timer? _demoTimer;

  String _demoText = 'My secret note...';
  bool _demoTextInitialized = false;

  // Accent colors per page
  static const _pageAccents = <Color>[
    AppColors.accentPeach,
    AppColors.accentYellow,
    AppColors.accentCoral,
    AppColors.accentMint,
  ];

  static const _pageAccentBgs = <Color>[
    AppColors.accentPeachBg,
    AppColors.accentYellowBg,
    AppColors.accentCoralBg,
    AppColors.accentMintBg,
  ];

  static const _pageIcons = <IconData>[
    Icons.shield_outlined,
    Icons.auto_awesome_outlined,
    Icons.publish_outlined,
    Icons.group_outlined,
  ];

  List<String> get _pageTitles {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.onboardingSecureNotesTitle,
      l10n.onboardingAITitle,
      l10n.onboardingPublishTitle,
      l10n.onboardingCollaborateTitle,
    ];
  }

  List<String> get _pageDescriptions {
    final l10n = AppLocalizations.of(context)!;
    return [
      l10n.onboardingSecureNotesDesc,
      l10n.onboardingAIDesc,
      l10n.onboardingPublishDesc,
      l10n.onboardingCollaborateDesc,
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    _demoTimer?.cancel();
    super.dispose();
  }

  void _startDemo() {
    _demoTimer?.cancel();
    setState(() {
      _demoActive = true;
      _demoCharIndex = 0;
      _demoLockVisible = false;
      _demoSyncVisible = false;
    });

    _demoTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_demoCharIndex < _demoText.length) {
        setState(() => _demoCharIndex++);
      } else {
        timer.cancel();
        Future.delayed(AppDurations.animation, () {
          if (!mounted) return;
          setState(() => _demoLockVisible = true);
          Future.delayed(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            setState(() => _demoSyncVisible = true);
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (!mounted || !_demoActive) return;
              _startDemo();
            });
          });
        });
      }
    });
  }

  void _stopDemo() {
    _demoTimer?.cancel();
    _demoActive = false;
  }

  Future<void> _requestPermissionsAndContinue() async {
    try {
      final notifService = LocalNotificationService();
      await notifService.init();
    } catch (_) {}
    if (mounted) {
      await _markSeenAndGo('/auth/register');
    }
  }

  Future<void> _markSeenAndGo(String route) async {
    const storage = AppSecureStorage.instance;
    await storage.write(key: 'has_seen_onboarding', value: 'true');
    globalContainer.read(hasSeenOnboardingProvider.notifier).state = true;
    if (mounted) {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_demoTextInitialized) {
      _demoText = l10n.demoSecretNote;
      _demoTextInitialized = true;
    }
    final isLastPage = _currentPage == _totalPages - 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg =
        isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // -- Top row: skip on the right --
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => _markSeenAndGo('/auth/login'),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                    child: Text(l10n.skip),
                  ),
                ],
              ),
            ),

            // -- Brand wordmark header --
            const _Wordmark(),

            // -- Page content --
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _totalPages,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  if (index == 2) {
                    _startDemo();
                  } else {
                    _stopDemo();
                  }
                },
                itemBuilder: (context, index) {
                  final titles = _pageTitles;
                  final descs = _pageDescriptions;
                  if (index == 2) {
                    return _buildDemoPage(
                      context,
                      titles[index],
                      descs[index],
                      _pageAccents[index],
                      _pageAccentBgs[index],
                    );
                  }
                  return _buildStaticPage(
                    context,
                    _pageIcons[index],
                    titles[index],
                    descs[index],
                    _pageAccents[index],
                    _pageAccentBgs[index],
                    showMascot: index == 0,
                  );
                },
              ),
            ),

            // -- Bottom nav: dots on the left, circular next button right --
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Row(
                children: [
                  _DotIndicator(
                    count: _totalPages,
                    current: _currentPage,
                    activeColor: primaryColor,
                  ),
                  const Spacer(),
                  PressableScale(
                    onPressed: () {
                      if (isLastPage) {
                        _requestPermissionsAndContinue();
                      } else {
                        _controller.nextPage(
                          duration: AppDurations.animation,
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.3),
                            offset: const Offset(0, 4),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Static page (pages 0, 1, 3). Page 0 shows the sticky-note mascot.
  // ---------------------------------------------------------------------------
  Widget _buildStaticPage(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color accent,
    Color accentBg, {
    bool showMascot = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration: sticky-note mascot on page 0, icon tile otherwise.
          if (showMascot)
            const _StickyNoteMascot()
          else
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: isDark
                    ? accent.withValues(alpha: 0.12)
                    : accentBg,
                borderRadius: BorderRadius.circular(48),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.15),
                    offset: const Offset(0, 8),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 40,
                    color: isDark ? accent : accent.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),

          const SizedBox(height: AppSpacing.xl),

          // Headline (handwriting voice)
          Text(
            title,
            style: AppTextStyles.handwritingTitle.copyWith(
              fontSize: 30,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.md),

          // Supporting text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
            child: Text(
              description,
              style: AppTextStyles.caption.copyWith(
                fontSize: 14,
                height: 1.6,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Interactive demo page (page 2 — index 2)
  // ---------------------------------------------------------------------------
  Widget _buildDemoPage(
    BuildContext context,
    String title,
    String description,
    Color accent,
    Color accentBg,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardBg : AppColors.lightCardBg;
    final typedText = _demoText.substring(0, _demoCharIndex);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Smaller illustration for demo page
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDark
                  ? accent.withValues(alpha: 0.12)
                  : accentBg,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.15),
                  offset: const Offset(0, 8),
                  blurRadius: 32,
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 28,
                  color: isDark ? accent : accent.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            title,
            style: AppTextStyles.handwritingTitle.copyWith(
              fontSize: 28,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.s12),

          Text(
            description,
            style: AppTextStyles.caption.copyWith(
              fontSize: 14,
              height: 1.6,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.xl),

          // -- Mock note card demo --
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.mdOf(Theme.of(context).brightness),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fake note input
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkInputFill
                        : AppColors.lightInputFill,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          typedText.isEmpty ? ' ' : typedText,
                          style: AppTextStyles.body,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_demoCharIndex < _demoText.length)
                        _BlinkingCursor(color: accent),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.md),

                // Lock -> Cloud animation row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_demoLockVisible)
                      Icon(
                        Icons.lock,
                        size: 28,
                        color: accent,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .scale(
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1.0, 1.0),
                            duration: 400.ms,
                          ),
                    if (_demoLockVisible && _demoSyncVisible)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Icon(
                          Icons.arrow_forward,
                          size: 20,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary,
                        ).animate().fadeIn(duration: 200.ms),
                      ),
                    if (_demoSyncVisible)
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 28,
                        color: accent,
                      )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .scale(
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1.0, 1.0),
                            duration: 400.ms,
                          ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brand wordmark header: handwritten "AnyNote" with a golden sparkle
// ---------------------------------------------------------------------------
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.md),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            'AnyNote',
            style: AppTextStyles.handwritingDisplay.copyWith(
              fontSize: 48,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
          // Small golden sparkle at the top-right of the wordmark
          const Positioned(
            top: -2,
            right: -16,
            child: Text(
              '✦',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sticky-note mascot: rotated yellow note with a smiley face, an overlapping
// pencil silhouette, and a few tiny sparkles around it.
// ---------------------------------------------------------------------------
class _StickyNoteMascot extends StatelessWidget {
  const _StickyNoteMascot();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brightness = isDark ? Brightness.dark : Brightness.light;

    return SizedBox(
      width: 230,
      height: 190,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Yellow sticky note, slightly rotated
          Positioned(
            left: 36,
            top: 14,
            child: Transform.rotate(
              angle: -0.1, // about -6 degrees
              child: Container(
                width: 152,
                height: 152,
                decoration: BoxDecoration(
                  color: AppColors.accentYellow,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: AppColors.accentYellowText.withValues(alpha: 0.2),
                  ),
                  boxShadow: AppShadows.mdOf(brightness),
                ),
                child: const Center(
                  child: _SmileyFace(
                    color: AppColors.slate700,
                    width: 68,
                    height: 44,
                  ),
                ),
              ),
            ),
          ),

          // Pencil silhouette overlapping the note
          Positioned(
            right: 26,
            bottom: 2,
            child: Transform.rotate(
              angle: -0.65,
              child: const Icon(
                AppIcons.edit,
                size: 60,
                color: AppColors.slate500,
              ),
            ),
          ),

          // Tiny sparkles around the composition
          const Positioned(
            top: 0,
            left: 18,
            child: Text(
              '✦',
              style: TextStyle(fontSize: 18, color: AppColors.warning),
            ),
          ),
          Positioned(
            bottom: 34,
            left: 6,
            child: Text(
              '✦',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.accentLavender
                    : AppColors.accentLavenderText,
              ),
            ),
          ),
          const Positioned(
            top: 66,
            right: 6,
            child: Text(
              '·',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.accentLavender,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Simple smiley face drawn with two dots and an arc
// ---------------------------------------------------------------------------
class _SmileyFace extends StatelessWidget {
  final Color color;
  final double width;
  final double height;

  const _SmileyFace({
    required this.color,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SmileyPainter(color: color),
      ),
    );
  }
}

class _SmileyPainter extends CustomPainter {
  final Color color;

  const _SmileyPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Two eyes as filled dots.
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final eyeRadius = size.width * 0.07;
    canvas.drawCircle(
      Offset(size.width * 0.28, size.height * 0.28),
      eyeRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.72, size.height * 0.28),
      eyeRadius,
      dotPaint,
    );

    // Smile as a downward arc.
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;
    final arcRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.34),
      width: size.width * 0.46,
      height: size.height * 0.9,
    );
    canvas.drawArc(arcRect, 0.35 * 3.14159, 0.65 * 3.14159, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _SmileyPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// Animated dot indicator
// ---------------------------------------------------------------------------
class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  final Color activeColor;

  const _DotIndicator({
    required this.count,
    required this.current,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark
        ? AppColors.darkDisabled
        : AppColors.lightDisabled;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: AppDurations.mediumAnimation,
          curve: Curves.easeInOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Blinking cursor widget
// ---------------------------------------------------------------------------
class _BlinkingCursor extends StatefulWidget {
  final Color color;

  const _BlinkingCursor({required this.color});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return false;
      setState(() => _visible = !_visible);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _visible ? 1.0 : 0.0,
      child: Text(
        '|',
        style: TextStyle(
          color: widget.color,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
