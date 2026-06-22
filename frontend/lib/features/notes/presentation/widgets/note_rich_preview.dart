import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/note_envelope.dart';

/// Lightweight formatted preview of a note's body for the note list.
///
/// Decrypts the note's content and renders it as a [RichText] built from the
/// Quill Delta's ops (bold / italic / underline / strikethrough / headings),
/// so the list card shows the note the same way the editor does — without
/// spinning up a heavyweight QuillEditor per card (which would jank a long
/// list). Sync-envelope corruption is unwrapped first.
class NoteRichPreview extends ConsumerStatefulWidget {
  final Note note;

  /// Max lines of preview text.
  final int maxLines;

  /// Base text color.
  final Color? color;

  const NoteRichPreview({
    super.key,
    required this.note,
    this.maxLines = 4,
    this.color,
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
        ops = decoded
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
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
    final base = AppTextStyles.body.copyWith(color: widget.color);

    if (_ops == null && _plainFallback == null) {
      return const SizedBox.shrink(); // still decrypting
    }

    if (_ops == null) {
      return Text(
        _plainFallback ?? '',
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        style: base,
      );
    }

    return RichText(
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      text: _opsToSpan(_ops!, base),
    );
  }

  /// Build a [TextSpan] tree from Quill Delta ops, applying inline attributes.
  TextSpan _opsToSpan(List<Map<String, dynamic>> ops, TextStyle base) {
    final children = <TextSpan>[];
    for (final op in ops) {
      final insert = op['insert'];
      if (insert is! String || insert.isEmpty) continue;
      final attrs =
          op['attributes'] is Map ? op['attributes'] as Map : const {};
      children.add(TextSpan(text: insert, style: _styleFor(attrs, base)));
    }
    return TextSpan(style: base, children: children);
  }

  TextStyle _styleFor(Map attrs, TextStyle base) {
    var s = base;
    if (attrs['bold'] == true) {
      s = s.copyWith(fontWeight: FontWeight.bold);
    }
    if (attrs['italic'] == true) {
      s = s.copyWith(fontStyle: FontStyle.italic);
    }
    if (attrs['underline'] == true || attrs['strike'] == true) {
      s = s.copyWith(
        decoration: attrs['underline'] == true && attrs['strike'] == true
            ? TextDecoration.combine(
                [TextDecoration.underline, TextDecoration.lineThrough])
            : attrs['underline'] == true
                ? TextDecoration.underline
                : TextDecoration.lineThrough,
      );
    }
    if (attrs['code'] == true) {
      s = s.copyWith(fontFamily: 'monospace');
    }
    final header = attrs['header'];
    if (header is int) {
      switch (header) {
        case 1:
          s = s.copyWith(
              fontSize: (base.fontSize ?? 16) * 1.5,
              fontWeight: FontWeight.bold);
          break;
        case 2:
          s = s.copyWith(
              fontSize: (base.fontSize ?? 16) * 1.3,
              fontWeight: FontWeight.bold);
          break;
        case 3:
          s = s.copyWith(
              fontSize: (base.fontSize ?? 16) * 1.15,
              fontWeight: FontWeight.w600);
          break;
      }
    }
    return s;
  }
}
