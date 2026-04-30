/// Reusable UI components for the AnyNote design system.
///
/// This file contains commonly repeated widget patterns extracted into
/// self-contained, configurable components. They are designed for gradual
/// adoption -- existing screens can import and use them without any migration.
///
/// Components:
/// - [AppEmptyState]          Empty state placeholder (icon + title + CTA)
/// - [AppLoadingCard]         Skeleton / shimmer loading placeholder for cards
/// - [AppErrorCard]           Error display with optional retry button
/// - [AppSyncBadge]           Compact sync status indicator
/// - [AppSectionHeader]       Section header with title and optional trailing action
/// - [SettingsGroupHeader]    iOS-style grouped settings section header
/// - [SettingsGroup]          Rounded card container for a group of settings items
/// - [SettingsItem]           Single settings row with icon circle, title, subtitle, trailing
/// - [StaggeredGroup]         Animated wrapper that fades in a group with stagger delay
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../error/error.dart';
import '../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

// =============================================================================
// AppEmptyState
// =============================================================================

/// A centered empty-state placeholder with an icon, title, optional subtitle,
/// and an optional call-to-action button.
///
/// This is the canonical empty-state widget for the app. It centralises the
/// layout, spacing, and typography so that every screen presents a consistent
/// experience when there is no data to show.
///
/// ```dart
/// AppEmptyState(
///   icon: Icons.note_add_outlined,
///   title: 'No notes yet',
///   subtitle: 'Tap the button to create your first note',
///   actionLabel: 'New Note',
///   onAction: () => context.push('/notes/new'),
/// )
/// ```
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: theme.disabledColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: TextStyle(color: theme.disabledColor),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// AppLoadingCard
// =============================================================================

/// A skeleton loading placeholder that mimics a card layout.
///
/// Displays animated shimmer bars for a title line, two body lines, and a
/// trailing badge. Useful as a placeholder inside [ListView] or [GridView]
/// builders while data is loading.
///
/// The shimmer animation uses a subtle highlight sweep that works in both
/// light and dark themes.
class AppLoadingCard extends StatefulWidget {
  /// Whether to show the compact grid-variant layout.
  final bool isGrid;

  const AppLoadingCard({super.key, this.isGrid = false});

  @override
  State<AppLoadingCard> createState() => _AppLoadingCardState();
}

class _AppLoadingCardState extends State<AppLoadingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Warm-tinted shimmer: uses theme surface colors for a cohesive feel.
    final baseColor = theme.brightness == Brightness.light
        ? AppTheme.lightDivider
        : AppTheme.darkInputFill;
    final highlightColor = theme.brightness == Brightness.light
        ? AppTheme.lightInputFill
        : AppTheme.darkBorder;

    return Card(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) {
              final slidePercent = _controller.value;
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor,
                  highlightColor,
                  baseColor,
                ],
                stops: [
                  (slidePercent - 0.3).clamp(0.0, 1.0),
                  slidePercent,
                  (slidePercent + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds);
            },
            child: child,
          );
        },
        child: widget.isGrid ? _buildGridSkeleton() : _buildListSkeleton(),
      ),
    );
  }

  Widget _buildListSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _bar(height: 16, widthFraction: 0.6)),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: _bar(height: 16, widthFraction: 1.0),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _bar(height: 12, widthFraction: 1.0),
          const SizedBox(height: 6),
          _bar(height: 12, widthFraction: 0.7),
          const SizedBox(height: 8),
          _bar(height: 10, widthFraction: 0.3),
        ],
      ),
    );
  }

  Widget _buildGridSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(height: 14, widthFraction: 0.8),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(height: 10, widthFraction: 1.0),
                const SizedBox(height: 6),
                _bar(height: 10, widthFraction: 0.9),
                const SizedBox(height: 6),
                _bar(height: 10, widthFraction: 0.6),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _bar(height: 10, widthFraction: 0.4),
        ],
      ),
    );
  }

  Widget _bar({required double height, required double widthFraction}) {
    return FractionallySizedBox(
      widthFactor: widthFraction,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

// =============================================================================
// AppErrorCard
// =============================================================================

/// A card that displays an error message with an optional retry button.
///
/// Shows the error icon from [ErrorDisplay.errorIcon], a human-readable
/// message from [ErrorDisplay.userMessage], and an optional "Retry" button.
/// Designed to replace the ad-hoc error Card patterns found across screens.
///
/// ```dart
/// AppErrorCard(
///   error: appError,
///   onRetry: () => ref.invalidate(someProvider),
/// )
/// ```
class AppErrorCard extends StatelessWidget {
  /// The mapped [AppException] to display.
  final AppException error;

  /// Optional retry callback. When provided, a "Retry" button is shown.
  final VoidCallback? onRetry;

  /// Optional override for the title text. Defaults to "Something went wrong".
  final String? title;

  const AppErrorCard({
    super.key,
    required this.error,
    this.onRetry,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = ErrorDisplay.errorIcon(error);
    final message =
        ErrorDisplay.userMessage(error, AppLocalizations.of(context));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.error),
            const SizedBox(height: 8),
            Text(
              title ??
                  (AppLocalizations.of(context)?.somethingWentWrong ??
                      'Something went wrong'),
              style: theme.textTheme.titleSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              style: TextStyle(fontSize: 12, color: theme.disabledColor),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(AppLocalizations.of(context)?.retry ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// AppSyncBadge
// =============================================================================

/// Compact sync status indicator for inline use inside list tiles or cards.
///
/// Wraps the same visual logic as [SyncStatusBadge] in a slightly more
/// opinionated widget that also handles the "no sync needed" (offline-only)
/// case and offers an optional text label beside the icon.
///
/// ```dart
/// trailing: AppSyncBadge(isSynced: note.isSynced, hasConflict: note.hasConflict),
/// ```
class AppSyncBadge extends StatelessWidget {
  final bool isSynced;
  final bool hasConflict;
  final bool showLabel;

  const AppSyncBadge({
    super.key,
    required this.isSynced,
    this.hasConflict = false,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final props = _statusProperties(l10n);

    return Tooltip(
      message: props.tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(props.icon, size: 16, color: props.color),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              props.label,
              style: TextStyle(fontSize: 12, color: props.color),
            ),
          ],
        ],
      ),
    );
  }

  ({IconData icon, Color color, String tooltip, String label})
      _statusProperties(AppLocalizations? l10n) {
    if (hasConflict) {
      return (
        icon: Icons.cloud_off,
        color: Colors.red,
        tooltip: l10n?.syncConflictBadge ?? 'Sync conflict',
        label: l10n?.conflictLabel ?? 'Conflict',
      );
    }
    if (isSynced) {
      return (
        icon: Icons.cloud_done,
        color: Colors.green,
        tooltip: l10n?.syncedLabel ?? 'Synced',
        label: l10n?.syncedLabel ?? 'Synced',
      );
    }
    return (
      icon: Icons.cloud_upload,
      color: Colors.orange,
      tooltip: l10n?.pendingSyncBadge ?? 'Pending sync',
      label: l10n?.pendingSyncLabel ?? 'Pending',
    );
  }
}

// =============================================================================
// AppSectionHeader
// =============================================================================

/// A section header with a title and an optional trailing action widget.
///
/// Centralises the repeated pattern of a small, primary-colored title
/// followed by an optional action link or button. Used in settings,
/// publish, and compose screens.
///
/// ```dart
/// AppSectionHeader(
///   title: 'Account',
///   trailing: TextButton(onPressed: () => ..., child: Text('Edit')),
/// )
/// ```
class AppSectionHeader extends StatelessWidget {
  /// The section title text.
  final String title;

  /// An optional widget displayed at the trailing edge (e.g. a button).
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// =============================================================================
// iOS-style Grouped Settings Components
// =============================================================================

/// A caption-style section header used above [SettingsGroup] cards.
///
/// Displays left-aligned, warm tertiary-colored text. Used as the title above
/// each grouped section of settings items.
///
/// ```dart
/// SettingsGroupHeader(title: 'Account'),
/// SettingsGroup(
///   children: [
///     SettingsItem(icon: Icons.person, title: 'Email', subtitle: 'user@example.com'),
///   ],
/// )
/// ```
class SettingsGroupHeader extends StatelessWidget {
  final String title;

  const SettingsGroupHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use tertiary text color: in light mode it is a warm muted grey,
    // in dark mode it is a warm darker muted tone.
    final color = theme.textTheme.bodySmall?.color ?? theme.disabledColor;

    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// A rounded card container that groups multiple [SettingsItem] widgets.
///
/// Renders a Material card with 12px border radius, warm surface color,
/// and a subtle warm border. Items inside are separated by thin dividers
/// that respect the horizontal padding. Wrap each logical section of
/// settings in one [SettingsGroup].
///
/// ```dart
/// SettingsGroup(
///   children: [
///     SettingsItem(icon: Icons.person, title: 'Email', ...),
///     SettingsItem(icon: Icons.badge, title: 'Plan', ...),
///   ],
/// )
/// ```
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const SettingsGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Warm card background and border matching the theme card tokens.
    final cardColor = isDark ? AppTheme.darkCardBg : AppTheme.lightCardBg;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _buildChildren(),
      ),
    );
  }

  Widget _buildChildren() {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Divider(height: 1, thickness: 0.5),
            ),
        ],
      ],
    );
  }
}

/// A single settings row with icon circle, title, subtitle, and trailing widget.
///
/// The icon is rendered inside a warm-tinted circle (32x32). Title uses
/// theme body style with on-surface color; subtitle uses caption style with
/// warm secondary color. Tapping produces a subtle warm ink splash.
///
/// ```dart
/// SettingsItem(
///   icon: Icons.shield_outlined,
///   title: 'Encryption',
///   subtitle: 'E2E encryption active',
///   trailing: Icon(Icons.chevron_right),
///   onTap: () => context.push('/settings/security'),
/// )
/// ```
class SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const SettingsItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _SettingsItemRaw(
      onTap: onTap,
      semanticsLabel: subtitle != null ? '$title: $subtitle' : title,
      child: Row(
        children: [
          const SizedBox(width: 12),
          // Icon in warm-tinted circle
          IconCircle(icon: icon, color: iconColor),
          const SizedBox(width: 12),
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// A settings item styled with the error/danger color for destructive actions
/// like "Sign Out" or "Delete All Data".
class DestructiveSettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const DestructiveSettingsItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return _SettingsItemRaw(
      onTap: onTap,
      semanticsLabel: title,
      child: Row(
        children: [
          const SizedBox(width: 12),
          IconCircle(icon: icon, color: errorColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: errorColor,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: errorColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// Raw tappable row wrapper that provides the warm ink splash highlight.
class _SettingsItemRaw extends StatelessWidget {
  final VoidCallback? onTap;
  final String? semanticsLabel;
  final Widget child;

  const _SettingsItemRaw({
    this.onTap,
    this.semanticsLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final splashColor = theme.colorScheme.primary.withValues(alpha: 0.08);

    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: splashColor,
          highlightColor: splashColor,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A 32x32 circle with a tinted fill containing an icon.
///
/// Used by settings items and sync sections. Optional [color] defaults to the
/// theme's primary color. Circle fill uses 12% alpha (light) / 15% alpha (dark).
class IconCircle extends StatelessWidget {
  final IconData icon;
  final Color? color;

  const IconCircle({super.key, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveColor = color ?? colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: isDark ? 0.15 : 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: effectiveColor),
    );
  }
}

/// An animated wrapper that fades in a child widget with a stagger delay.
///
/// Each instance animates over 200ms. The [staggerIndex] controls how many
/// 50ms delays to add before the animation starts, creating a cascading
/// reveal effect when multiple groups appear together.
///
/// Respects the reduce motion accessibility setting - when enabled, the child
/// is rendered immediately without animation.
///
/// ```dart
/// StaggeredGroup(
///   staggerIndex: 0,
///   child: SettingsGroup(children: [...]),
/// )
/// ```
class StaggeredGroup extends StatefulWidget {
  final int staggerIndex;
  final Widget child;

  const StaggeredGroup({
    super.key,
    required this.staggerIndex,
    required this.child,
  });

  @override
  State<StaggeredGroup> createState() => _StaggeredGroupState();
}

class _StaggeredGroupState extends State<StaggeredGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;
  Timer? _delayTimer;
  bool _hasStartedAnimation = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scale = Tween<double>(
      begin: 0.98,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasStartedAnimation) {
      _hasStartedAnimation = true;
      // Check if reduce motion is enabled
      final reduceMotion = MediaQuery.disableAnimationsOf(context);

      if (reduceMotion) {
        // Skip animation entirely - show immediately
        _controller.value = 1.0;
      } else {
        // Stagger: each group waits 50ms * staggerIndex before starting.
        final delay = Duration(milliseconds: 50 * widget.staggerIndex);
        _delayTimer = Timer(delay, () {
          if (mounted) _controller.forward();
        });
      }
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _delayTimer = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          child: widget.child,
        ),
      ),
    );
  }
}
