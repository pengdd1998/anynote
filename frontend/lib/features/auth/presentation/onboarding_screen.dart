import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/pressable_scale.dart';

/// Four-page onboarding screen with interactive guided walkthrough.
///
/// Uses a [PageView] with custom dot indicators. Page 3 features an
/// animated demo showing note creation, encryption, and sync.
/// On completion the user is redirected to registration; skipping
/// goes to login.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;
  static const _totalPages = 4;

  // Demo animation state for page 3 (index 2)
  bool _demoActive = false;
  int _demoCharIndex = 0;
  bool _demoLockVisible = false;
  bool _demoSyncVisible = false;
  Timer? _demoTimer;

  // Demo text for the typing animation on page 3.
  // Initialized from l10n on first build.
  String _demoText = 'My secret note...';
  bool _demoTextInitialized = false;

  List<_OnboardingPageData> _buildPages(AppLocalizations l10n) => [
        _OnboardingPageData(
          icon: Icons.shield_outlined,
          title: l10n.onboardingSecureNotesTitle,
          description: l10n.onboardingSecureNotesDesc,
        ),
        _OnboardingPageData(
          icon: Icons.auto_awesome_outlined,
          title: l10n.onboardingAITitle,
          description: l10n.onboardingAIDesc,
        ),
        // Page 3 is the interactive demo -- handled separately in itemBuilder.
        _OnboardingPageData(
          icon: Icons.publish_outlined,
          title: l10n.onboardingPublishTitle,
          description: l10n.onboardingPublishDesc,
        ),
        _OnboardingPageData(
          icon: Icons.group_outlined,
          title: l10n.onboardingCollaborateTitle,
          description: l10n.onboardingCollaborateDesc,
        ),
      ];

  @override
  void dispose() {
    _controller.dispose();
    _demoTimer?.cancel();
    super.dispose();
  }

  /// Start or restart the character-by-character demo animation.
  void _startDemo() {
    _demoTimer?.cancel();
    setState(() {
      _demoActive = true;
      _demoCharIndex = 0;
      _demoLockVisible = false;
      _demoSyncVisible = false;
    });

    // Type characters one by one (~80ms each).
    _demoTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_demoCharIndex < _demoText.length) {
        setState(() => _demoCharIndex++);
      } else {
        timer.cancel();
        // After typing finishes, show lock icon.
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() => _demoLockVisible = true);
          // Then show sync icon.
          Future.delayed(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            setState(() => _demoSyncVisible = true);
            // Reset cycle after a pause so it loops while the page is visible.
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (!mounted || !_demoActive) return;
              _startDemo();
            });
          });
        });
      }
    });
  }

  /// Stop the demo animation.
  void _stopDemo() {
    _demoTimer?.cancel();
    _demoActive = false;
  }

  Future<void> _markSeenAndGo(String route) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'has_seen_onboarding', value: 'true');
    if (mounted) {
      context.go(route);
    }
  }

  // ---------------------------------------------------------------------------
  // Warm-tinted inactive dot color
  // ---------------------------------------------------------------------------
  static const _warmGreyDot = Color(0xFFD5CCC2);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!_demoTextInitialized) {
      _demoText = l10n.demoSecretNote;
      _demoTextInitialized = true;
    }
    final pages = _buildPages(l10n);
    final isLastPage = _currentPage == pages.length - 1;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Warm background -- use explicit colors matching AppTheme surfaces.
    const scaffoldBgLight = Color(0xFFFAF8F5);
    const scaffoldBgDark = Color(0xFF1A1614);
    final scaffoldBg = isDark ? scaffoldBgDark : scaffoldBgLight;

    final inactiveDotColor = isDark ? const Color(0xFF4A4340) : _warmGreyDot;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // -- Top row: progress dots (left) + Skip button (right) -----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  // Dot indicators
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_totalPages, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color:
                              isActive ? colorScheme.primary : inactiveDotColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  // Skip text button
                  TextButton(
                    onPressed: () => _markSeenAndGo('/auth/login'),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onSurfaceVariant,
                    ),
                    child: Text(l10n.skip),
                  ),
                ],
              ),
            ),

            // -- Page content ----------------------------------------------------
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  // Trigger demo on page 3 (index 2), stop otherwise.
                  if (index == 2) {
                    _startDemo();
                  } else {
                    _stopDemo();
                  }
                },
                itemBuilder: (context, index) {
                  if (index == 2) {
                    return _buildDemoPage(context, pages[index], colorScheme);
                  }
                  return _buildStaticPage(context, pages[index], colorScheme);
                },
              ),
            ),

            // -- Bottom action buttons -------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: PressableScale(
                      onPressed: () {
                        if (isLastPage) {
                          _markSeenAndGo('/auth/register');
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      child: FilledButton(
                        onPressed: null, // handled by PressableScale
                        child: Text(isLastPage ? l10n.getStarted : l10n.next),
                      ),
                    ),
                  ),
                  if (!isLastPage) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => _markSeenAndGo('/auth/login'),
                      child: Text(l10n.skip),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Static page builder (pages 1, 2, 4)
  // ---------------------------------------------------------------------------
  Widget _buildStaticPage(
    BuildContext context,
    _OnboardingPageData page,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            page.icon,
            size: 100,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Interactive demo page (page 3 -- index 2)
  // ---------------------------------------------------------------------------
  Widget _buildDemoPage(
    BuildContext context,
    _OnboardingPageData page,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final inputFill = isDark ? AppTheme.darkInputFill : AppTheme.lightInputFill;

    final typedText = _demoText.substring(0, _demoCharIndex);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title & description
          Icon(
            page.icon,
            size: 64,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            page.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            page.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // -- Mock note card demo -------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fake note text field
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          typedText.isEmpty ? ' ' : typedText,
                          style: Theme.of(context).textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Blinking cursor
                      if (_demoCharIndex < _demoText.length)
                        _BlinkingCursor(colorScheme: colorScheme),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Lock + Sync icons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lock icon with fade-in
                    if (_demoLockVisible)
                      Icon(
                        Icons.lock,
                        size: 28,
                        color: colorScheme.primary,
                      ).animate().fadeIn(duration: 400.ms).scale(
                            begin: const Offset(0.5, 0.5),
                            end: const Offset(1.0, 1.0),
                            duration: 400.ms,
                          ),
                    const SizedBox(width: 24),
                    // Arrow from lock to cloud
                    if (_demoLockVisible && _demoSyncVisible)
                      Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: colorScheme.onSurfaceVariant,
                      ).animate().fadeIn(duration: 200.ms),
                    const SizedBox(width: 24),
                    // Sync icon with fade-in
                    if (_demoSyncVisible)
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 28,
                        color: colorScheme.primary,
                      ).animate().fadeIn(duration: 400.ms).scale(
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
// Blinking cursor widget for the typing animation
// ---------------------------------------------------------------------------
class _BlinkingCursor extends StatefulWidget {
  final ColorScheme colorScheme;

  const _BlinkingCursor({required this.colorScheme});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> {
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    // Toggle cursor visibility every 500ms.
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
          color: widget.colorScheme.primary,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}

/// Data model for a single onboarding page.
class _OnboardingPageData {
  final IconData icon;
  final String title;
  final String description;

  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.description,
  });
}
