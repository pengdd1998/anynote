import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service for exporting notes to PDF format.
///
/// Uses the `pdf` package to generate PDF documents from markdown content,
/// with support for CJK (Chinese, Japanese, Korean) text via a bundled font.
/// The `printing` package is used for the system print dialog.
class PdfExportService {
  PdfExportService._();

  /// Cached CJK font loaded once and reused across calls.
  static pw.Font? _cjkFont;

  /// Load a CJK-compatible font for PDF rendering.
  ///
  /// Uses Noto Sans SC from the bundle, which covers Simplified Chinese,
  /// Traditional Chinese, Japanese, and Korean characters.
  static Future<pw.Font> _loadCjkFont() async {
    if (_cjkFont != null) return _cjkFont!;
    try {
      _cjkFont = pw.Font.ttf(
        await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf'),
      );
    } catch (_) {
      // Fallback to the default PDF font if the bundled font is unavailable.
      _cjkFont = pw.Font.helvetica();
    }
    return _cjkFont!;
  }

  /// Convert a markdown note to PDF bytes.
  ///
  /// [title] is rendered as a large heading at the top of the document.
  /// [content] is parsed for common markdown constructs (headings, bold,
  /// italic, code blocks, lists, blockquotes) and rendered with proper
  /// formatting. Page numbers appear at the bottom of each page.
  static Future<Uint8List> exportToPdf(String title, String content) async {
    final font = await _loadCjkFont();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: font, bold: font, italic: font),
    );

    final parsedBlocks = _parseMarkdown(content);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        header: (context) {
          // Only show the title header on the first page.
          if (context.pageNumber == 1) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Text(
                title,
                style: pw.TextStyle(font: font, fontSize: 24),
              ),
            );
          }
          return pw.SizedBox.shrink();
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.center,
            margin: const pw.EdgeInsets.only(top: 16),
            child: pw.Text(
              '${context.pageNumber} / ${context.pagesCount}',
              style: pw.TextStyle(font: font, fontSize: 9),
            ),
          );
        },
        build: (context) {
          return parsedBlocks;
        },
      ),
    );

    return doc.save();
  }

  /// Generate a PDF and share it using the platform share sheet.
  static Future<void> sharePdf(String title, String content) async {
    if (kIsWeb) return; // share_plus does not support file sharing on web.

    final bytes = await exportToPdf(title, content);
    final dir = await getTemporaryDirectory();
    final safeTitle = title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'_+'), '_');
    final filename = '${safeTitle}_anynote.pdf';
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: title,
    );
  }

  /// Generate a PDF and open the system print dialog.
  static Future<void> printPdf(String title, String content) async {
    final bytes = await exportToPdf(title, content);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: title,
    );
  }

  // ── Markdown parsing ───────────────────────────────────

  /// Parse markdown content into a list of pdf widgets.
  static List<pw.Widget> _parseMarkdown(String content) {
    final blocks = <pw.Widget>[];
    final lines = content.split('\n');
    final buffer = StringBuffer();
    bool inCodeBlock = false;
    final codeBuffer = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Handle fenced code blocks.
      if (line.trimLeft().startsWith('```')) {
        if (inCodeBlock) {
          // End of code block.
          blocks.add(_buildCodeBlock(codeBuffer.toString()));
          codeBuffer.clear();
          inCodeBlock = false;
        } else {
          // Start of code block -- flush any pending paragraph text first.
          _flushParagraph(blocks, buffer);
          inCodeBlock = true;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBuffer.writeln(line);
        continue;
      }

      // Check for heading lines.
      final headingMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (headingMatch != null) {
        _flushParagraph(blocks, buffer);
        final level = headingMatch.group(1)!.length;
        final text = headingMatch.group(2)!;
        blocks.add(_buildHeading(text, level));
        continue;
      }

      // Check for horizontal rule.
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})\s*$').hasMatch(line)) {
        _flushParagraph(blocks, buffer);
        blocks.add(pw.Divider());
        continue;
      }

      // Check for blockquote.
      if (line.trimLeft().startsWith('> ')) {
        _flushParagraph(blocks, buffer);
        final quoteText = line.trimLeft().substring(2);
        blocks.add(_buildBlockquote(quoteText));
        continue;
      }

      // Check for unordered list items.
      final ulMatch = RegExp(r'^(\s*)[-*]\s+(.+)$').firstMatch(line);
      if (ulMatch != null) {
        _flushParagraph(blocks, buffer);
        final indent = ulMatch.group(1)!.length;
        final text = ulMatch.group(2)!;
        blocks.add(_buildListItem(text, indent: indent));
        continue;
      }

      // Check for ordered list items.
      final olMatch = RegExp(r'^(\s*)\d+\.\s+(.+)$').firstMatch(line);
      if (olMatch != null) {
        _flushParagraph(blocks, buffer);
        final indent = olMatch.group(1)!.length;
        final text = olMatch.group(2)!;
        blocks.add(_buildListItem(text, indent: indent, ordered: true));
        continue;
      }

      // Empty line signals paragraph break.
      if (line.trim().isEmpty) {
        _flushParagraph(blocks, buffer);
        continue;
      }

      // Accumulate paragraph text.
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(line);
    }

    // Flush any remaining content.
    if (inCodeBlock) {
      blocks.add(_buildCodeBlock(codeBuffer.toString()));
    }
    _flushParagraph(blocks, buffer);

    return blocks;
  }

  /// Flush the paragraph buffer into the blocks list.
  static void _flushParagraph(List<pw.Widget> blocks, StringBuffer buffer) {
    if (buffer.isEmpty) return;
    blocks.add(_buildParagraph(buffer.toString()));
    buffer.clear();
  }

  /// Build a heading widget at the given level.
  static pw.Widget _buildHeading(String text, int level) {
    final fontSize = switch (level) {
      1 => 20.0,
      2 => 18.0,
      3 => 16.0,
      4 => 14.0,
      5 => 13.0,
      _ => 12.0,
    };

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12, bottom: 6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  /// Build a paragraph widget with inline formatting support.
  static pw.Widget _buildParagraph(String text) {
    final spans = _parseInlineFormatting(text);
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Text(
        spans.map((s) => s.text).join(),
        style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
      ),
    );
  }

  /// Build a code block with a grey background.
  static pw.Widget _buildCodeBlock(String code) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      child: pw.Text(
        code.trimRight(),
        style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5),
      ),
    );
  }

  /// Build a blockquote with a left border.
  static pw.Widget _buildBlockquote(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8, left: 12),
      padding: const pw.EdgeInsets.only(left: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.grey400, width: 2),
        ),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
      ),
    );
  }

  /// Build a list item with a bullet and optional indentation.
  static pw.Widget _buildListItem(
    String text, {
    int indent = 0,
    bool ordered = false,
  }) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 4, left: (indent * 12).toDouble()),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            ordered ? '  ' : '  • ',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
            ),
          ),
        ],
      ),
    );
  }

  /// Represents an inline text span with optional bold/italic formatting.
  static Iterable<({String text, bool bold, bool italic})>
      _parseInlineFormatting(
    String text,
  ) sync* {
    // Simple inline formatting: bold (**text**), italic (*text*), code (`text`).
    final pattern = RegExp(r'(\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`)');
    var remaining = text;

    while (remaining.isNotEmpty) {
      final match = pattern.firstMatch(remaining);
      if (match == null) {
        yield (text: remaining, bold: false, italic: false);
        break;
      }

      // Emit text before the match.
      if (match.start > 0) {
        yield (
          text: remaining.substring(0, match.start),
          bold: false,
          italic: false,
        );
      }

      if (match.group(2) != null) {
        // Bold: **text**
        yield (text: match.group(2)!, bold: true, italic: false);
      } else if (match.group(3) != null) {
        // Italic: *text*
        yield (text: match.group(3)!, bold: false, italic: true);
      } else if (match.group(4) != null) {
        // Inline code: `text`
        yield (text: match.group(4)!, bold: false, italic: false);
      }

      remaining = remaining.substring(match.end);
    }
  }
}
