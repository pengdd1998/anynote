import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_durations.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/notifications/local_notification_service.dart';
import '../../../main.dart';

/// Warm, emotional onboarding carousel.
///
/// Four full-screen pages with generous whitespace, centered illustrations
/// in soft rounded containers, large friendly headlines, pill-shaped CTA,
/// and animated pagination dots. Page 3 features a live encryption demo.
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
      _markSeenAndGo('/auth/register');
    }
  }

  Future<void> _markSeenAndGo(String route) async {
    const storage = FlutterSecureStorage();
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
    final accent = _pageAccents[_currentPage];

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // -- Top row: dots + skip --
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _DotIndicator(
                    count: _totalPages,
                    current: _currentPage,
                    activeColor: accent,
                  ),
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
                  );
                },
              ),
            ),

            // -- Bottom CTA --
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: PressableScale(
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
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accent,
                              accent.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.3),
                              offset: const Offset(0, 4),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            isLastPage ? l10n.getStarted : l10n.next,
                            style: AppTextStyles.body.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
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
  // Static page (pages 0, 1, 3)
  // ---------------------------------------------------------------------------
  Widget _buildStaticPage(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color accent,
    Color accentBg,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration container — large rounded circle with accent bg
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

          // Headline
          Text(
            title,
            style: AppTextStyles.display.copyWith(
              fontSize: 28,
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
              style: AppTextStyles.body.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
                height: 1.7,
                fontSize: 16,
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
            style: AppTextStyles.display.copyWith(
              fontSize: 26,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: AppSpacing.s12),

          Text(
            description,
            style: AppTextStyles.body.copyWith(
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary,
              height: 1.6,
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
