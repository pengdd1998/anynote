import 'dart:convert';

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
      _controller!
          .document
          .insert(0, stripObjectPlaceholders(trimmed));
    } else {
      try {
        final deltaList = jsonDecode(trimmed) as List;
        final doc = quill.Document.fromJson(
          sanitizeDeltaOps(deltaList),
        );
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        // Fallback: treat as plain text.
        _controller = quill.QuillController.basic();
        _controller!
            .document
            .insert(0, stripObjectPlaceholders(trimmed));
      }
    }
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
