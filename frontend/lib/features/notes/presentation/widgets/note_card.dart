import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/accessibility/a11y_utils.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/color_utils.dart';
import '../../../../core/theme/paper_tokens.dart';
import '../../../../core/widgets/paper_doodle.dart';
import '../../../../core/widgets/paper_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/note_envelope.dart';
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
/// soft matching borders, subtle shadows, and design token typography.
/// Grid cards read as pastel sticky notes; image notes render with a
/// prominent clipped image header above a warm card info section.
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

  /// Plain-text body used for the derived title. Normalizes notes whose
  /// plainContent holds Delta JSON (e.g. from an older broken restore) so
  /// raw JSON is never rendered as the card title.
  String get _plainBody {
    final content = note.plainContent;
    if (content == null || content.trim().isEmpty) return '';
    return plainTextFromStoredContent(content);
  }

  /// True when the note title is derived from the body's first line, in
  /// which case the rich preview skips that line to avoid duplication.
  bool get _titleComesFromContent {
    final content = _plainBody;
    if (content.trim().isEmpty) return false;
    final line = content.trim().split('\n').first.trim();
    return line.isNotEmpty;
  }

  /// Parsed note color, or null if no color is set.
  Color? get _noteColor {
    final hex = note.color;
    if (hex == null) return null;
    return parseHexColor(hex);
  }

  static final _pastelColors = <String, Color>{
    'yellow': AppColors.paperYellow,
    'peach': AppColors.paperPink,
    'green': AppColors.paperGreen,
    'pink': AppColors.paperPink,
    'blue': AppColors.paperLavender,
    'orange': AppColors.paperYellow,
    'lavender': AppColors.paperLavender,
    'purple': AppColors.paperLavender,
  };

  /// Paper tone override for a user-picked note color, or null to let
  /// [PaperSurface] cycle the token palette by list index.
  Color? _paperToneOverride(BuildContext context, Color? noteColor) {
    if (noteColor == null) return null;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorStr = note.color?.toLowerCase();
    if (colorStr != null) {
      for (final entry in _pastelColors.entries) {
        if (colorStr.contains(entry.key)) {
          final tone = entry.value;
          return isDark
              ? Color.alphaBlend(tone.withAlpha(58), AppColors.darkCardBg)
              : tone;
        }
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
    final firstLine = () {
      final content = _plainBody;
      if (content.trim().isEmpty) return null;
      final line = content.trim().split('\n').first.trim();
      return line.isEmpty ? null : line;
    }();
    final legacy = note.plainTitle;
    final title = firstLine ??
        (legacy != null && legacy.isNotEmpty ? legacy : untitled);
    final hasImage = previewImagePath != null && !kIsWeb;
    final noteColor = _noteColor;

    // Grid cards are sheets of sticky-note paper (PaperSurface applies the
    // paper tokens: tone cycle, tilt, Post-it radius, warm shadow). List
    // rows stay neutral straight cards for scannability.
    final card = PaperSurface(
      seed: listIndex,
      tone: _isGrid
          ? (isSelected
              ? (isDark
                  ? AppColors.primary.withAlpha(40)
                  : AppColors.primarySoft)
              : hasImage
                  ? (isDark ? AppColors.darkCardBg : AppColors.lightCardBg)
                  : _paperToneOverride(context, noteColor))
          : (isDark ? AppColors.darkCardBg : AppColors.lightCardBg),
      tilted: _isGrid,
      selected: isSelected,
      borderRadius:
          _isGrid ? null : BorderRadius.circular(AppRadius.md),
      border: isSelected
          ? null // PaperSurface draws the periwinkle selection ring.
          : (_isGrid
              ? null // Paper edge: tone + shadow only (mockup style).
              : Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                )),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onLongPressStart: onLongPress != null
              ? (details) {
                  HapticFeedback.mediumImpact();
                  onLongPress!(details.globalPosition);
                }
              : null,
          child: InkWell(
            onTap: onTap,
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
    final previewSkipsTitle = _titleComesFromContent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Image header — proportionally scaled, clipped to rounded top corners.
        if (hasImage)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xs),
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

        // Info section — on the warm card surface for image notes, or the
        // pastel sticky-note background otherwise (mockup style).
        Container(
          width: double.infinity,
          color: hasImage
              ? (isDark ? AppColors.darkCardBg : AppColors.lightCardBg)
              : null,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handwritten title with pin/lock icons.
              _buildTitleRow(context, theme, isDark, title),

              // Handwritten body — rendered the same way as the editor.
              const SizedBox(height: AppSpacing.s4),
              NoteRichPreview(
                note: note,
                maxLines: 4,
                skipFirstLine: previewSkipsTitle,
                handwritten: true,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),

              // Tags
              if (tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s8),
                  child: TagChipsRow(tags: tags),
                ),

              const SizedBox(height: AppSpacing.s4),

              // Date row with corner doodle (sticky-note footer).
              _buildDateRow(context, theme, isDark, withDoodle: true),
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
    final previewSkipsTitle = _titleComesFromContent;

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
                // Handwritten title with pin/lock icons.
                _buildTitleRow(context, theme, isDark, title),
                // Formatted body — rendered the same way as the editor.
                const SizedBox(height: AppSpacing.s8),
                NoteRichPreview(
                  note: note,
                  maxLines: 3,
                  skipFirstLine: previewSkipsTitle,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                if (tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.s8),
                    child: TagChipsRow(tags: tags),
                  ),
                const SizedBox(height: AppSpacing.s8),
                _buildDateRow(context, theme, isDark),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.isPinned)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s4, top: 3),
            child: Semantics(
              label: AppLocalizations.of(context)?.pinnedNote,
              child: ExcludeSemantics(
                child: Icon(
                  Icons.push_pin,
                  size: _isGrid ? 14 : 16,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        if (isLocked)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.s4, top: 3),
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
        // Handwritten note title (first line of content), near-black.
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.handwritingBody.copyWith(
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.lightTextPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRow(
    BuildContext context,
    ThemeData theme,
    bool isDark, {
    bool withDoodle = false,
  }) {
    final paper = PaperTokens.of(context);
    final timestamp = Text(
      time,
      style: AppTextStyles.handwritingCaption.copyWith(color: paper.inkMuted),
    );

    if (!withDoodle) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [timestamp],
      );
    }

    // Sticky-note footer like the mockup: timestamp bottom-left, a small
    // hand-drawn ink sketch bottom-right. The doodle is keyed to the note
    // id so it never changes between list rebuilds.
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        timestamp,
        ExcludeSemantics(
          child: PaperDoodle(
            kind: PaperDoodleKindX.forSeed(note.id.hashCode),
            color: paper.inkDoodle.withAlpha(150),
          ),
        ),
      ],
    );
  }
}
