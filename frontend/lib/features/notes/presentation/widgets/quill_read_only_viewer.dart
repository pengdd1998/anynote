import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../domain/note_envelope.dart';
import '../embeds/local_image_embed.dart';
import '../embeds/table_embed.dart';
import '../embeds/transclusion_embed.dart';
import '../embeds/wiki_link_embed.dart';

/// Read-only viewer for Quill Delta JSON content.
///
/// Renders note content using the same embed builders as the editor,
/// ensuring consistent appearance between edit, detail, and inline views.
class QuillReadOnlyViewer extends StatefulWidget {
  /// Delta JSON string (e.g. `[{"insert":"hello"},{"insert":"\n"}]`).
  final String deltaJson;

  /// Optional padding around the content.
  final EdgeInsets padding;

  /// Optional Quill style theme override. When null the editor falls back
  /// to its built-in defaults, keeping parity with the editor screens.
  final quill.DefaultStyles? customStyles;

  const QuillReadOnlyViewer({
    super.key,
    required this.deltaJson,
    this.padding = EdgeInsets.zero,
    this.customStyles,
  });

  @override
  State<QuillReadOnlyViewer> createState() => _QuillReadOnlyViewerState();
}

class _QuillReadOnlyViewerState extends State<QuillReadOnlyViewer> {
  quill.QuillController? _controller;
  String? _lastJson;

  @override
  void didUpdateWidget(QuillReadOnlyViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deltaJson != widget.deltaJson) {
      _initController();
    }
  }

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    final json = widget.deltaJson;
    if (json == _lastJson) return;
    _lastJson = json;

    _controller?.dispose();

    final trimmed = json.trim();
    if (!trimmed.startsWith('[')) {
      // Plain text — wrap in a minimal Delta document.
      _controller = quill.QuillController.basic();
      _controller!.document.insert(0, stripObjectPlaceholders(trimmed));
    } else {
      try {
        final deltaList = jsonDecode(trimmed) as List;
        final doc = quill.Document.fromJson(
          _dropTrailingBlankLines(sanitizeDeltaOps(deltaList)),
        );
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        // Fallback: treat as plain text.
        _controller = quill.QuillController.basic();
        _controller!.document.insert(0, stripObjectPlaceholders(trimmed));
      }
    }
  }

  /// A note often ends on a few empty lines — that is where the cursor was
  /// left. The writer's copy keeps them; a reader was shown a sheet half a
  /// screen taller than its text. One line break stays at the end, the empty
  /// lines after the last of the text do not.
  ///
  /// Done on the Delta, before there is a document. Asked to delete at its
  /// end, a document puts the line break back — Quill keeps a document
  /// ending on one — so the last empty line could not be deleted at all.
  static List<Map<String, dynamic>> _dropTrailingBlankLines(
    List<Map<String, dynamic>> ops,
  ) {
    // The line breaks at the very end. An insert of nothing but line breaks
    // adds its whole length; one that ends in text adds the run after its
    // last other character and, like an embed, ends the count there.
    var trailing = 0;
    for (final op in ops.reversed) {
      final insert = op['insert'];
      if (insert is! String) break;
      var end = insert.length;
      while (end > 0 && insert.codeUnitAt(end - 1) == 0x0A) {
        end--;
      }
      trailing += insert.length - end;
      if (end > 0) break;
    }

    // One stays: it is the document's last line break.
    var extra = trailing - 1;
    if (extra <= 0) return ops;
    final kept = <Map<String, dynamic>>[];
    for (final op in ops.reversed) {
      final insert = op['insert'];
      if (extra > 0 && insert is String) {
        final cut = math.min(extra, insert.length);
        extra -= cut;
        final rest = insert.substring(0, insert.length - cut);
        if (rest.isNotEmpty) kept.add({...op, 'insert': rest});
        continue;
      }
      kept.add(op);
    }
    return kept.reversed.toList();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _controller!.readOnly = true;
    return quill.QuillEditor(
      controller: _controller!,
      focusNode: FocusNode(canRequestFocus: false),
      scrollController: ScrollController(),
      config: quill.QuillEditorConfig(
        padding: widget.padding,
        showCursor: false,
        autoFocus: false,
        expands: false,
        scrollable: false,
        customStyles: widget.customStyles,
        embedBuilders: const [
          LocalImageEmbedBuilder(),
          TableEmbedBuilder(),
          WikiLinkEmbedBuilder(),
          TransclusionEmbedBuilder(),
        ],
      ),
    );
  }
}
