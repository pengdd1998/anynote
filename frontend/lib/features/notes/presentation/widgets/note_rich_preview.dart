import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/note_envelope.dart';

/// Lightweight formatted preview of a note's body for the note list.
///
/// Decrypts the note's content and renders it as a [RichText] that mirrors the
/// editor's rendering — inline styles (bold / italic / underline / strike /
/// code / links) AND block structure (bullet lists, numbered lists,
/// blockquotes, H1–H3) — without spinning up a heavyweight QuillEditor per
/// card (which would jank a long list). Sync-envelope corruption is unwrapped
/// first.
class NoteRichPreview extends ConsumerStatefulWidget {
  final Note note;

  /// Max lines of preview text.
  final int maxLines;

  /// Base text color.
  final Color? color;

  /// When true, the first content line is hidden. Used by the note card,
  /// which renders the first line as the handwritten title itself.
  final bool skipFirstLine;

  const NoteRichPreview({
    super.key,
    required this.note,
    this.maxLines = 6,
    this.color,
    this.skipFirstLine = false,
  });

  @override
  ConsumerState<NoteRichPreview> createState() => _NoteRichPreviewState();
}

class _NoteRichPreviewState extends ConsumerState<NoteRichPreview> {
  List<Map<String, dynamic>>? _ops;
  String? _plainFallback;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final crypto = ref.read(cryptoServiceProvider);
    String content = widget.note.plainContent ?? '';

    if (crypto.isUnlocked) {
      try {
        final decrypted =
            await crypto.decryptForItem(widget.note.id, widget.note.encryptedContent);
        if (decrypted != null && decrypted.isNotEmpty) {
          content = decrypted;
        }
      } catch (_) {
        // Fall back to plainContent.
      }
    }

    // Unwrap any sync-envelope corruption, then parse as a Quill Delta.
    content = unwrapSyncEnvelope(content);
    List<Map<String, dynamic>>? ops;
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        ops = decoded.whereType<Map<String, dynamic>>().toList(growable: false);
      }
    } catch (_) {
      // Not a Delta — treat as plain text below.
    }

    if (!mounted) return;
    setState(() {
      _ops = ops;
      _plainFallback = (ops == null) ? content : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Compact preview base (smaller than the editor's body size) so the card
    // reads as a preview, not a full document.
    final base = AppTextStyles.body.copyWith(
      color: widget.color,
      height: 1.4,
      fontSize: 13,
    );

    if (_ops == null && _plainFallback == null) {
      return const SizedBox.shrink(); // still decrypting
    }

    if (_ops == null) {
      var fallback = _plainFallback ?? '';
      if (widget.skipFirstLine) {
        // Drop the first line — it is rendered as the card title.
        fallback = fallback.split('\n').skip(1).join('\n');
      }
      return Text(
        fallback,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }

    return RichText(
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      text: _deltaToSpan(_ops!, base, Theme.of(context)),
    );
  }

  // ── Delta → TextSpan (line-aware, mirrors the editor) ──────────────────

  TextSpan _deltaToSpan(
    List<Map<String, dynamic>> ops,
    TextStyle base,
    ThemeData theme,
  ) {
    final lines = _splitIntoLines(ops);
    if (widget.skipFirstLine && lines.isNotEmpty) {
      // Drop the first line — it is rendered as the card title.
      lines.removeAt(0);
    }
    final spans = <InlineSpan>[];
    var ordered = 0;
    for (final line in lines) {
      final blockStyle = _blockStyle(line.blockAttrs, base, theme);
      final children = <TextSpan>[];

      // List markers.
      if (line.blockAttrs['list'] == 'bullet') {
        ordered = 0;
        children.add(TextSpan(text: '•  ', style: blockStyle));
      } else if (line.blockAttrs['list'] == 'ordered') {
        ordered++;
        children.add(TextSpan(text: '$ordered.  ', style: blockStyle));
      } else {
        ordered = 0;
      }

      // Blockquote gutter.
      if (line.blockAttrs['blockquote'] == true) {
        children.add(
          TextSpan(
            text: '│  ',
            style: blockStyle.copyWith(
              color: (blockStyle.color ?? theme.colorScheme.onSurface)
                  .withAlpha(120),
            ),
          ),
        );
      }

      // Inline runs (bold/italic/underline/strike/code/link).
      for (final run in line.runs) {
        children.add(
          TextSpan(text: run.text, style: _inlineStyle(run.attrs, blockStyle, theme)),
        );
      }

      spans.add(TextSpan(style: blockStyle, children: children));
      spans.add(const TextSpan(text: '\n'));
    }
    return TextSpan(style: base, children: spans);
  }

  /// Split Delta ops into lines. A line ends at a `\n`; the op containing the
  /// newline carries the line's block attributes (list/header/blockquote), per
  /// the Quill Delta convention.
  List<_Line> _splitIntoLines(List<Map<String, dynamic>> ops) {
    final lines = <_Line>[];
    var runs = <_Run>[];
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is! String || insert.isEmpty) continue; // skip embeds
      final attrs = op['attributes'] is Map<String, dynamic>
          ? op['attributes'] as Map<String, dynamic>
          : <String, dynamic>{};
      final segments = insert.split('\n');
      for (var i = 0; i < segments.length; i++) {
        if (segments[i].isNotEmpty) {
          runs.add(_Run(segments[i], attrs));
        }
        if (i < segments.length - 1) {
          lines.add(_Line(List.of(runs), attrs));
          runs = <_Run>[];
        }
      }
    }
    if (runs.isNotEmpty) lines.add(_Line(runs, <String, dynamic>{}));
    return lines;
  }

  TextStyle _blockStyle(Map<String, dynamic> attrs, TextStyle base, ThemeData theme) {
    var s = base;
    final header = attrs['header'];
    if (header is int) {
      switch (header) {
        case 1:
          s = s.copyWith(fontSize: (base.fontSize ?? 13) * 1.35, fontWeight: FontWeight.bold);
          break;
        case 2:
          s = s.copyWith(fontSize: (base.fontSize ?? 13) * 1.2, fontWeight: FontWeight.bold);
          break;
        case 3:
          s = s.copyWith(fontSize: (base.fontSize ?? 13) * 1.1, fontWeight: FontWeight.w600);
          break;
      }
    }
    if (attrs['blockquote'] == true) {
      s = s.copyWith(fontStyle: FontStyle.italic);
    }
    return s;
  }

  TextStyle _inlineStyle(Map<String, dynamic> attrs, TextStyle base, ThemeData theme) {
    var s = base;
    if (attrs['bold'] == true) s = s.copyWith(fontWeight: FontWeight.bold);
    if (attrs['italic'] == true) s = s.copyWith(fontStyle: FontStyle.italic);
    if (attrs['underline'] == true || attrs['strike'] == true) {
      s = s.copyWith(
        decoration: attrs['underline'] == true && attrs['strike'] == true
            ? TextDecoration.combine([TextDecoration.underline, TextDecoration.lineThrough])
            : attrs['underline'] == true
                ? TextDecoration.underline
                : TextDecoration.lineThrough,
      );
    }
    if (attrs['code'] == true) s = s.copyWith(fontFamily: 'RobotoMono');
    if (attrs['link'] is String) {
      s = s.copyWith(color: theme.colorScheme.primary, decoration: TextDecoration.underline);
    }
    return s;
  }
}

class _Run {
  final String text;
  final Map<String, dynamic> attrs;
  const _Run(this.text, this.attrs);
}

class _Line {
  final List<_Run> runs;
  final Map<String, dynamic> blockAttrs;
  const _Line(this.runs, this.blockAttrs);
}
