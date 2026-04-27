import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../main.dart';

const String _wikiLinkEmbedKey = 'wiki_link';

/// Embed builder for wiki-style [[note links]] in Quill editor.
///
/// Wiki links are stored as custom embeds with type 'wiki_link' and data
/// containing the target note ID and/or title. When rendered, they appear
/// as tappable, styled links that navigate to the linked note.
class WikiLinkEmbedBuilder extends quill.EmbedBuilder {
  const WikiLinkEmbedBuilder();

  @override
  String get key => _wikiLinkEmbedKey;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final node = embedContext.node;
    final data = node.value.data;

    if (data == null) {
      return const SizedBox.shrink();
    }

    final linkData = _parseLinkData(data);
    if (linkData == null) {
      return const _BrokenWikiLinkWidget(displayText: '??');
    }

    return WikiLinkWidget(
      noteId: linkData['noteId'] as String?,
      title: linkData['title'] as String?,
      readOnly: embedContext.readOnly,
      textStyle: embedContext.textStyle,
    );
  }

  /// Parses wiki link data from the embed node.
  ///
  /// Data can be either:
  /// 1. A JSON string: '{"noteId":"uuid","title":"Note Title"}'
  /// 2. A Map directly (already parsed)
  Map<String, dynamic>? _parseLinkData(dynamic data) {
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
        debugPrint('[WikiLinkEmbed] failed to parse link data JSON: $e');
        return null;
      }
    }
    return null;
  }
}

/// Rendered wiki link widget displaying the linked note title.
///
/// Shows as a styled, tappable link that navigates to the target note.
/// If the note cannot be found, displays a broken link indicator.
class WikiLinkWidget extends ConsumerStatefulWidget {
  final String? noteId;
  final String? title;
  final bool readOnly;
  final TextStyle? textStyle;

  const WikiLinkWidget({
    super.key,
    this.noteId,
    this.title,
    required this.readOnly,
    this.textStyle,
  });

  @override
  ConsumerState<WikiLinkWidget> createState() => _WikiLinkWidgetState();
}

class _WikiLinkWidgetState extends ConsumerState<WikiLinkWidget> {
  String? _resolvedTitle;
  bool _isLoading = true;
  bool _isBroken = false;

  @override
  void initState() {
    super.initState();
    _resolveLink();
  }

  @override
  void didUpdateWidget(WikiLinkWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noteId != widget.noteId || oldWidget.title != widget.title) {
      _resolveLink();
    }
  }

  Future<void> _resolveLink() async {
    setState(() {
      _isLoading = true;
      _isBroken = false;
    });

    final db = ref.read(databaseProvider);
    String displayTitle = widget.title ?? '??';

    if (widget.noteId != null) {
      try {
        final note = await db.notesDao.getNoteById(widget.noteId!);
        if (note != null &&
            note.plainTitle != null &&
            note.plainTitle!.isNotEmpty) {
          displayTitle = note.plainTitle!;
        } else {
          _isBroken = true;
        }
      } catch (e) {
        debugPrint('[WikiLinkWidget] failed to resolve note title: $e');
        _isBroken = true;
      }
    }

    if (mounted) {
      setState(() {
        _resolvedTitle = displayTitle;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildWidget(context, '...', false);
    }

    return _buildWidget(
      context,
      _resolvedTitle ?? '??',
      _isBroken,
    );
  }

  Widget _buildWidget(BuildContext context, String text, bool isBroken) {
    final theme = Theme.of(context);

    final linkStyle =
        (widget.textStyle ?? theme.textTheme.bodyMedium)?.copyWith(
      color: isBroken ? theme.colorScheme.error : theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor:
          isBroken ? theme.colorScheme.error : theme.colorScheme.primary,
    );

    final backgroundColor = isBroken
        ? theme.colorScheme.errorContainer.withValues(alpha: 0.1)
        : theme.colorScheme.primaryContainer.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isBroken
              ? theme.colorScheme.error.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: MouseRegion(
        cursor: widget.readOnly ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: widget.readOnly && widget.noteId != null
              ? () => _navigateToNote(context, widget.noteId!)
              : null,
          child: Text(
            '[[$text]]',
            style: linkStyle,
          ),
        ),
      ),
    );
  }

  void _navigateToNote(BuildContext context, String noteId) {
    context.push('/notes/$noteId');
  }
}

/// Widget for displaying broken wiki links (notes that don't exist).
class _BrokenWikiLinkWidget extends StatelessWidget {
  final String displayText;

  const _BrokenWikiLinkWidget({required this.displayText});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '[[$displayText]]',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}

/// Creates a wiki link embed data map that can be inserted into a Quill document.
Map<String, dynamic> createWikiLinkData({
  required String? noteId,
  required String title,
}) {
  return {
    'noteId': noteId,
    'title': title,
  };
}

/// Inserts a wiki link embed at the current cursor position in the Quill controller.
void insertWikiLinkEmbed({
  required quill.QuillController controller,
  required String? noteId,
  required String title,
}) {
  final linkData = createWikiLinkData(
    noteId: noteId,
    title: title,
  );

  final embed = quill.CustomBlockEmbed(
    _wikiLinkEmbedKey,
    jsonEncode(linkData),
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

/// Regex for matching wiki-style [[note title]] syntax in plain text.
final wikiLinkPattern = RegExp(
  r'\[\[([^\]]+)\]\]',
  multiLine: true,
);

/// Extracts all wiki link references from plain text.
///
/// Returns a list of maps containing 'title' and optional 'noteId' for each
/// [[link]] found in the text.
List<Map<String, String>> extractWikiLinks(String text) {
  final matches = wikiLinkPattern.allMatches(text);
  return matches.map((match) {
    final title = match.group(1) ?? '';
    return {
      'title': title,
      'fullMatch': match.group(0) ?? '[[]]',
    };
  }).toList();
}

/// Replaces wiki link markdown syntax with actual wiki link embeds.
///
/// This converts [[Note Title]] text in the document to proper embed blocks.
void convertWikiLinksToEmbeds(quill.QuillController controller) {
  final plainText = controller.document.toPlainText();
  final links = extractWikiLinks(plainText);

  if (links.isEmpty) return;

  int offset = 0;
  final doc = controller.document;

  for (final link in links) {
    final title = link['title']!;
    final fullMatch = link['fullMatch']!;

    final index = plainText.indexOf(fullMatch, offset);
    if (index == -1) continue;

    final linkData = createWikiLinkData(
      noteId: null,
      title: title,
    );

    final embed = quill.CustomBlockEmbed(
      _wikiLinkEmbedKey,
      jsonEncode(linkData),
    );

    doc.replace(index, fullMatch.length, embed);
    offset = index + 1;
  }
}
