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
import 'note_rich_preview.dart';

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

  /// Pre-extracted first image path from the note content, stored in DB.
  final String? previewImagePath;

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
    this.previewImagePath,
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
    'peach': AppColors.notePeach,
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
      if (isDark) return pastel.withAlpha(30);
      // Light mode: white card with very faint pastel tint (alpha 25/255 ≈ 10%)
      return Color.alphaBlend(
        pastel.withAlpha(25),
        AppColors.lightCardBg,
      );
    }
    final colorStr = note.color?.toLowerCase();
    if (colorStr != null) {
      for (final entry in _pastelColors.entries) {
        if (colorStr.contains(entry.key)) return entry.value;
      }
    }
    return noteColor.withAlpha(40);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    // Notes have no stored title — derive the list label from the first line
    // of content; fall back to a legacy stored title, then "Untitled".
    final title = () {
      final content = note.plainContent;
      if (content != null && content.trim().isNotEmpty) {
        final firstLine = content.trim().split('\n').first.trim();
        if (firstLine.isNotEmpty) return firstLine;
      }
      final legacy = note.plainTitle;
      if (legacy != null && legacy.isNotEmpty) return legacy;
      return untitled;
    }();
    final noteColor = _noteColor;

    final cardBgColor = isSelected
        ? colorScheme.primaryContainer.withAlpha(60)
        : _cardBackgroundColor(
            context,
            noteColor,
            colorScheme.surfaceContainerLow,
          );

    final radius = _isGrid ? AppRadius.lg : AppRadius.md;

    // Subtle colored border for grid cards (mockup style).
    final borderColor = _isGrid && !isSelected && !isDark
        ? AppColors.noteBorderColors[listIndex % AppColors.noteBorderColors.length]
        : null;

    final card = Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(radius),
        border: isSelected
            ? Border.all(
                color: colorScheme.primary.withAlpha(80),
                width: 1.5,
              )
            : borderColor != null
                ? Border.all(color: borderColor, width: 1)
                : (!_isGrid && !isDark
                    ? Border.all(color: AppColors.slate100, width: 1)
                    : null),
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
    final hasImage = previewImagePath != null && !kIsWeb;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image header — proportionally scaled, clipped to top corners
        if (hasImage)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.md),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200, minHeight: 80),
              child: Image.file(
                File(previewImagePath!),
                width: double.infinity,
                fit: BoxFit.fitWidth,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row with pin/lock icons
              _buildTitleRow(context, theme, isDark, title),

              // Formatted body — rendered the same way as the editor.
              const SizedBox(height: AppSpacing.s4),
              NoteRichPreview(
                note: note,
                maxLines: 5,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),

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
    final hasImage = previewImagePath != null && !kIsWeb;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleRow(context, theme, isDark, title),
                // Formatted body — rendered the same way as the editor.
                const SizedBox(height: AppSpacing.s8),
                NoteRichPreview(
                  note: note,
                  maxLines: 3,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.lightTextPrimary,
                ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s8),
                    child: TagChipsRow(tags: tags),
                  ),
                const SizedBox(height: AppSpacing.s8),
                _buildDateRow(theme, isDark),
              ],
            ),
          ),
          if (hasImage) ...[
            const SizedBox(width: AppSpacing.s12),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Image.file(
                  File(previewImagePath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
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
        // Notes have no separate title — the body is rendered formatted by
        // NoteRichPreview below, so this row only carries status icons.
      ],
    );
  }

  Widget _buildDateRow(ThemeData theme, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
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
}
