import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../main.dart';

const String _transclusionEmbedKey = 'transclusion';

/// Provider for watching a single note by ID.
/// Returns a stream that emits the note whenever it is updated.
final noteStreamProvider = StreamProvider.family<Note?, String>((ref, noteId) {
  final db = ref.watch(databaseProvider);
  return db.notesDao.watchNoteById(noteId);
});

/// Maximum depth for nested transclusions to prevent infinite loops.
const int maxTransclusionDepth = 5;

/// Embed builder for note transclusions ![[note]] in Quill editor.
///
/// Transclusions embed the full content of another note inline, similar to
/// Obsidian's ![[note]] syntax. The embedded content is rendered with a
/// visual border and includes controls to edit the original or unlink.
class TransclusionEmbedBuilder extends quill.EmbedBuilder {
  const TransclusionEmbedBuilder();

  @override
  String get key => _transclusionEmbedKey;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final node = embedContext.node;
    final data = node.value.data;

    if (data == null) {
      return const SizedBox.shrink();
    }

    final transclusionData = _parseTransclusionData(data);
    if (transclusionData == null) {
      return const _BrokenTransclusionWidget();
    }

    return TransclusionWidget(
      noteId: transclusionData['noteId'] as String?,
      title: transclusionData['title'] as String?,
      depth: (transclusionData['depth'] as int?) ?? 0,
      readOnly: embedContext.readOnly,
    );
  }

  /// Parses transclusion data from the embed node.
  ///
  /// Data can be either:
  /// 1. A JSON string: '{"noteId":"uuid","title":"Note Title","depth":0}'
  /// 2. A Map directly (already parsed)
  Map<String, dynamic>? _parseTransclusionData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (e) {
        debugPrint('[TransclusionEmbed] failed to parse transclusion data: $e');
        return null;
      }
    }
    return null;
  }
}

/// Rendered transclusion widget displaying the embedded note content.
///
/// Shows the full content of the referenced note with:
/// - Visual border and background
/// - Source note title as caption
/// - "Edit original" button
/// - "Unlink" button to convert to plain text
/// - Handles deleted notes and max depth limits
class TransclusionWidget extends ConsumerStatefulWidget {
  final String? noteId;
  final String? title;
  final int depth;
  final bool readOnly;

  const TransclusionWidget({
    super.key,
    this.noteId,
    this.title,
    this.depth = 0,
    required this.readOnly,
  });

  @override
  ConsumerState<TransclusionWidget> createState() => _TransclusionWidgetState();
}

class _TransclusionWidgetState extends ConsumerState<TransclusionWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    // Check depth limit first (doesn't require provider)
    if (widget.depth >= maxTransclusionDepth) {
      return _buildContainer(
        context,
        _DepthLimitContent(title: widget.title),
      );
    }

    // If no noteId, show broken state
    if (widget.noteId == null) {
      return _buildContainer(
        context,
        _BrokenTransclusionContent(title: widget.title),
      );
    }

    // Watch the note for live updates
    final noteAsync = ref.watch(noteStreamProvider(widget.noteId!));

    return noteAsync.when(
      data: (note) {
        if (note == null) {
          return _buildContainer(
            context,
            _BrokenTransclusionContent(title: widget.title),
          );
        }

        final displayTitle = note.plainTitle ?? 'Untitled';
        final content = note.plainContent ?? '';

        return _buildContainer(
          context,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(
                title: displayTitle,
                noteId: widget.noteId,
                isExpanded: _isExpanded,
                onToggle: () => setState(() => _isExpanded = !_isExpanded),
                onEdit: widget.noteId != null
                    ? () => _navigateToNote(context, widget.noteId!)
                    : null,
              ),
              if (_isExpanded && content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Text(
                    content,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => _buildContainer(
        context,
        const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, __) => _buildContainer(
        context,
        _BrokenTransclusionContent(title: widget.title),
      ),
    );
  }

  Widget _buildContainer(BuildContext context, Widget content) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: content,
    );
  }

  void _navigateToNote(BuildContext context, String noteId) {
    context.push('/notes/$noteId');
  }
}

/// Header for transcluded content showing title and action buttons.
class _Header extends StatelessWidget {
  final String title;
  final String? noteId;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback? onEdit;

  const _Header({
    required this.title,
    this.noteId,
    required this.isExpanded,
    required this.onToggle,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.link,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            onPressed: onToggle,
            tooltip: isExpanded ? 'Collapse' : 'Expand',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 16),
              onPressed: onEdit,
              tooltip: 'Edit original',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }
}

/// Content shown when the transcluded note is not found.
class _BrokenTransclusionContent extends StatelessWidget {
  final String? title;

  const _BrokenTransclusionContent({this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Note "${title ?? 'Untitled'}" not found or was deleted.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Content shown when transclusion depth exceeds limit.
class _DepthLimitContent extends StatelessWidget {
  final String? title;

  const _DepthLimitContent({this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.block,
            size: 16,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Nested transclusion limit reached for "$title".',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying broken transclusions.
class _BrokenTransclusionWidget extends StatelessWidget {
  const _BrokenTransclusionWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            'Invalid transclusion',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

/// Creates a transclusion embed data map.
Map<String, dynamic> createTransclusionData({
  required String? noteId,
  required String title,
  int depth = 0,
}) {
  return {
    'noteId': noteId,
    'title': title,
    'depth': depth,
  };
}

/// Inserts a transclusion embed at the current cursor position.
void insertTransclusionEmbed({
  required quill.QuillController controller,
  required String? noteId,
  required String title,
  int depth = 0,
}) {
  final transclusionData = createTransclusionData(
    noteId: noteId,
    title: title,
    depth: depth,
  );

  final embed = quill.CustomBlockEmbed(
    _transclusionEmbedKey,
    jsonEncode(transclusionData),
  );

  final index = controller.selection.baseOffset;
  final length = controller.selection.extentOffset - index;

  if (length > 0) {
    controller.replaceText(
      index,
      length,
      embed,
      TextSelection.collapsed(offset: index + 1),
    );
  } else {
    controller.document.insert(index, embed);
  }
}

/// Regex for matching ![[note title]] transclusion syntax.
final transclusionPattern = RegExp(
  r'!\[\[([^\]]+)\]\]',
  multiLine: true,
);

/// Extracts all transclusion references from plain text.
List<Map<String, String>> extractTransclusions(String text) {
  final matches = transclusionPattern.allMatches(text);
  return matches.map((match) {
    final title = match.group(1) ?? '';
    return {
      'title': title,
      'fullMatch': match.group(0) ?? '![[ ]]',
    };
  }).toList();
}

/// Replaces transclusion markdown syntax with actual embeds.
void convertTransclusionsToEmbeds(quill.QuillController controller) {
  final plainText = controller.document.toPlainText();
  final transclusions = extractTransclusions(plainText);

  if (transclusions.isEmpty) return;

  int offset = 0;
  final doc = controller.document;

  for (final transclusion in transclusions) {
    final title = transclusion['title']!;
    final fullMatch = transclusion['fullMatch']!;

    final index = plainText.indexOf(fullMatch, offset);
    if (index == -1) continue;

    final transclusionData = createTransclusionData(
      noteId: null,
      title: title,
      depth: 0,
    );

    final embed = quill.CustomBlockEmbed(
      _transclusionEmbedKey,
      jsonEncode(transclusionData),
    );

    doc.replace(index, fullMatch.length, embed);
    offset = index + 1;
  }
}
