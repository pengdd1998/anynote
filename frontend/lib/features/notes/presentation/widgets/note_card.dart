import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/accessibility/a11y_utils.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/color_utils.dart';
import '../../../../l10n/app_localizations.dart';
import 'tag_chips_row.dart';

/// Layout variant for [NoteCard].
enum NoteCardLayout {
  list,
  grid,
}

/// Card widget for displaying a note in list or staggered grid layout.
///
/// Uses the warm design system: generous rounded corners (AppRadius.md),
/// soft diffused shadows, no hard borders, and design token typography.
/// Image notes render with a prominent clipped image header.
class NoteCard extends StatelessWidget {
  final Note note;
  final String time;
  final List<Tag> tags;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onLongPress;
  final String untitled;
  final NoteCardLayout layout;
  final VoidCallback? onStatusTap;
  final VoidCallback? onPriorityTap;

  /// Whether the note is locked (read-only). Shows a lock icon on the card.
  final bool isLocked;

  /// Pre-loaded properties to avoid per-card database streams in lists.
  final List<NoteProperty>? properties;

  /// Index in the list, used for auto-cycling pastel colors.
  final int listIndex;

  const NoteCard({
    super.key,
    required this.note,
    required this.time,
    required this.tags,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    required this.untitled,
    this.layout = NoteCardLayout.grid,
    this.onStatusTap,
    this.onPriorityTap,
    this.isLocked = false,
    this.properties,
    this.listIndex = 0,
  });

  bool get _isGrid => layout == NoteCardLayout.grid;

  /// Parsed note color, or null if no color is set.
  Color? get _noteColor {
    final hex = note.color;
    if (hex == null) return null;
    return parseHexColor(hex);
  }

  static final _pastelColors = <String, Color>{
    'yellow': AppColors.noteYellow,
    'purple': AppColors.notePurple,
    'green': AppColors.noteGreen,
    'pink': AppColors.notePink,
    'blue': AppColors.noteBlue,
    'orange': AppColors.noteOrange,
  };

  Color _cardBackgroundColor(
    BuildContext context,
    Color? noteColor,
    Color defaultColor,
  ) {
    if (noteColor == null) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final pastel =
          AppColors.notePastels[listIndex % AppColors.notePastels.length];
      return isDark ? pastel.withAlpha(30) : pastel;
    }
    final colorStr = note.color?.toLowerCase();
    if (colorStr != null) {
      for (final entry in _pastelColors.entries) {
        if (colorStr.contains(entry.key)) return entry.value;
      }
    }
    return noteColor.withAlpha(40);
  }

  /// Extract the first image file path from the note content, if any.
  String? get _firstImagePath {
    final content = note.plainContent;
    if (content == null) return null;
    final regex = RegExp(r'!\[.*?\]\(file://([^)]+)\)');
    final match = regex.firstMatch(content);
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final title = note.plainTitle ?? untitled;
    final noteColor = _noteColor;

    final cardBgColor = isSelected
        ? colorScheme.primaryContainer.withAlpha(60)
        : _cardBackgroundColor(
            context,
            noteColor,
            colorScheme.surfaceContainerLow,
          );

    final radius = _isGrid ? AppRadius.md : AppRadius.sm;

    final card = Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(radius),
        border: isSelected
            ? Border.all(
                color: colorScheme.primary.withAlpha(80),
                width: 1.5,
              )
            : null,
        boxShadow: _isGrid ? AppShadows.smOf(theme.brightness) : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onLongPressStart: onLongPress != null
              ? (details) {
                  HapticFeedback.mediumImpact();
                  onLongPress!(details.globalPosition);
                }
              : null,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(radius),
            splashColor: colorScheme.primary.withAlpha(20),
            highlightColor: colorScheme.primary.withAlpha(10),
            child: _isGrid
                ? _buildGridContent(context, theme, isDark, title)
                : _buildListContent(context, theme, isDark, title),
          ),
        ),
      ),
    );

    return Semantics(
      label: A11yUtils.noteCardLabel(
        title: title,
        timeDescription: time,
        isPinned: note.isPinned,
        isSynced: note.isSynced,
      ),
      button: true,
      child: card,
    );
  }

  // ---------------------------------------------------------------------------
  // Grid layout (staggered / masonry)
  // ---------------------------------------------------------------------------

  Widget _buildGridContent(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    String title,
  ) {
    final preview = _previewText(50);
    final imagePath = _firstImagePath;
    final hasImage = imagePath != null && !kIsWeb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image header — prominent, clipped to top corners
        if (hasImage)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.md),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 140,
              child: Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s12,
            AppSpacing.s12,
            AppSpacing.s12,
            AppSpacing.s8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with pin/lock icons
              _buildTitleRow(context, theme, isDark, title),

              // Preview text
              if (preview.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s4),
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary,
                    height: 1.4,
                  ),
                ),
              ],

              // Tags
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s8),
                  child: TagChipsRow(tags: tags),
                ),

              const SizedBox(height: AppSpacing.s4),

              // Date row
              _buildDateRow(theme, isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // List layout
  // ---------------------------------------------------------------------------

  Widget _buildListContent(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    String title,
  ) {
    final preview = _previewText(100);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleRow(context, theme, isDark, title),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ],
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s8),
              child: TagChipsRow(tags: tags),
            ),
          const SizedBox(height: AppSpacing.s8),
          _buildDateRow(theme, isDark),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildTitleRow(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    String title,
  ) {
    return Row(
      children: [
        if (note.isPinned)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s4),
            child: Semantics(
              label: AppLocalizations.of(context)?.pinnedNote,
              child: ExcludeSemantics(
                child: Icon(
                  Icons.push_pin,
                  size: _isGrid ? 14 : 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        if (isLocked)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s4),
            child: ExcludeSemantics(
              child: Icon(
                Icons.lock_outline,
                size: _isGrid ? 12 : 14,
                color: (isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.lightTextTertiary)
                    .withAlpha(150),
              ),
            ),
          ),
        Expanded(
          child: Text(
            title,
            maxLines: _isGrid ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: (_isGrid
                    ? AppTextStyles.title
                    : AppTextStyles.headline.copyWith(fontSize: 18))
                .copyWith(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
              fontWeight: _isGrid ? FontWeight.w600 : FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRow(ThemeData theme, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule,
          size: _isGrid ? 11 : 13,
          color: (isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.lightTextTertiary)
              .withAlpha(180),
        ),
        const SizedBox(width: AppSpacing.s4),
        Text(
          time,
          style: AppTextStyles.caption.copyWith(
            fontSize: _isGrid ? 11 : 12,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
        ),
      ],
    );
  }

  String _previewText(int maxLen) {
    final content = note.plainContent;
    if (content == null) return '';
    // Strip markdown image syntax for preview.
    final cleaned = content.replaceAll(RegExp(r'!\[.*?\]\(file://[^)]+\)'), '').trim();
    if (cleaned.isEmpty) return '';
    return cleaned.length > maxLen
        ? '${cleaned.substring(0, maxLen)}...'
        : cleaned;
  }
}
