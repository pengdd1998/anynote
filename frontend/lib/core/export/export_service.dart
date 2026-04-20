import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Supported export formats.
enum ExportFormat { markdown, html, plainText }

/// Service for exporting notes to various file formats.
///
/// Generates files in the system temp directory and optionally shares them
/// using the platform share sheet via share_plus.
///
/// File-based export requires a native filesystem and is not supported on web.
/// All export methods throw [UnsupportedError] when running on web.
// TODO(web): Implement browser download using package:web / dart:js_interop.
class ExportService {
  /// Sanitize a title so it is safe to use as a filename component.
  static String _sanitizeTitle(String title) {
    return title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// Export a single note as a Markdown (.md) file.
  static Future<File> exportAsMarkdown(
    String title,
    String content,
    String noteId,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'File export is not supported on web platform',
      );
    }
    final dir = await getTemporaryDirectory();
    final sanitized = _sanitizeTitle(title);
    final suffix = noteId.length >= 8 ? noteId.substring(0, 8) : noteId;
    final file = File('${dir.path}/${sanitized}_$suffix.md');
    await file.writeAsString('# $title\n\n$content');
    return file;
  }

  /// Export a single note as an HTML file.
  static Future<File> exportAsHtml(
    String title,
    String content,
    String noteId,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'File export is not supported on web platform',
      );
    }
    final htmlContent = _markdownToHtml(content);
    final dir = await getTemporaryDirectory();
    final sanitized = _sanitizeTitle(title);
    final suffix = noteId.length >= 8 ? noteId.substring(0, 8) : noteId;
    final file = File('${dir.path}/${sanitized}_$suffix.html');
    await file.writeAsString(
      '<!DOCTYPE html>\n'
      '<html><head><meta charset="utf-8"><title>$title</title>\n'
      '<style>\n'
      'body{font-family:system-ui,-apple-system,sans-serif;'
      'max-width:800px;margin:0 auto;padding:20px;line-height:1.6;color:#333}\n'
      'h1{font-size:1.8em;border-bottom:1px solid #eee;padding-bottom:8px}\n'
      'h2{font-size:1.5em}\n'
      'h3{font-size:1.2em}\n'
      'code{background:#f0f0f0;padding:2px 6px;border-radius:3px;font-size:0.9em}\n'
      'pre{background:#f4f4f4;padding:16px;border-radius:8px;overflow-x:auto}\n'
      'pre code{background:none;padding:0}\n'
      'blockquote{border-left:3px solid #ccc;padding-left:16px;color:#666;margin:0}\n'
      'img{max-width:100%}\n'
      'a{color:#0066cc}\n'
      'ul,ol{padding-left:24px}\n'
      '</style></head>\n'
      '<body>\n'
      '<h1>${_escapeHtml(title)}</h1>\n'
      '$htmlContent\n'
      '</body></html>',
    );
    return file;
  }

  /// Export a single note as a plain text (.txt) file.
  static Future<File> exportAsPlainText(
    String title,
    String content,
    String noteId,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'File export is not supported on web platform',
      );
    }
    final dir = await getTemporaryDirectory();
    final sanitized = _sanitizeTitle(title);
    final suffix = noteId.length >= 8 ? noteId.substring(0, 8) : noteId;
    final file = File('${dir.path}/${sanitized}_$suffix.txt');
    await file.writeAsString('$title\n\n$content');
    return file;
  }

  /// Export a batch of notes into a single file.
  ///
  /// Notes are combined with clear separators. The format determines the file
  /// extension and how each note is rendered.
  static Future<File> exportBatch(
    List<({String title, String content, String id})> notes,
    ExportFormat format,
  ) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'File export is not supported on web platform',
      );
    }
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final File file;

    switch (format) {
      case ExportFormat.markdown:
        final buffer = StringBuffer();
        for (final note in notes) {
          buffer.writeln('# ${note.title}');
          buffer.writeln();
          buffer.writeln(note.content);
          buffer.writeln();
          buffer.writeln('---');
          buffer.writeln();
        }
        file = File('${dir.path}/anynote_export_$timestamp.md');
        await file.writeAsString(buffer.toString());

      case ExportFormat.html:
        final buffer = StringBuffer();
        for (final note in notes) {
          buffer.writeln('<article>');
          buffer.writeln('<h1>${_escapeHtml(note.title)}</h1>');
          buffer.writeln(_markdownToHtml(note.content));
          buffer.writeln('</article>');
          buffer.writeln('<hr>');
        }
        final htmlContent = buffer.toString();
        file = File('${dir.path}/anynote_export_$timestamp.html');
        await file.writeAsString(
          '<!DOCTYPE html>\n'
          '<html><head><meta charset="utf-8"><title>AnyNote Export</title>\n'
          '<style>\n'
          'body{font-family:system-ui,-apple-system,sans-serif;'
          'max-width:800px;margin:0 auto;padding:20px;line-height:1.6;color:#333}\n'
          'h1{font-size:1.8em;border-bottom:1px solid #eee;padding-bottom:8px}\n'
          'h2{font-size:1.5em}\n'
          'h3{font-size:1.2em}\n'
          'code{background:#f0f0f0;padding:2px 6px;border-radius:3px;font-size:0.9em}\n'
          'pre{background:#f4f4f4;padding:16px;border-radius:8px;overflow-x:auto}\n'
          'pre code{background:none;padding:0}\n'
          'blockquote{border-left:3px solid #ccc;padding-left:16px;color:#666;margin:0}\n'
          'img{max-width:100%}\n'
          'a{color:#0066cc}\n'
          'ul,ol{padding-left:24px}\n'
          'hr{border:none;border-top:1px solid #eee;margin:32px 0}\n'
          '</style></head>\n'
          '<body>\n'
          '$htmlContent\n'
          '</body></html>',
        );

      case ExportFormat.plainText:
        final buffer = StringBuffer();
        for (final note in notes) {
          buffer.writeln(note.title);
          buffer.writeln();
          buffer.writeln(note.content);
          buffer.writeln();
          buffer.writeln('=' * 40);
          buffer.writeln();
        }
        file = File('${dir.path}/anynote_export_$timestamp.txt');
        await file.writeAsString(buffer.toString());
    }

    return file;
  }

  /// Share a file using the platform share sheet.
  static Future<void> shareFile(File file, {String? subject}) async {
    if (kIsWeb) {
      throw UnsupportedError(
        'File sharing is not supported on web platform',
      );
    }
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject ?? 'AnyNote Export',
    );
  }

  /// Escape special HTML characters.
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  /// Convert a Markdown string to a simple HTML string using regex.
  ///
  /// This is a lightweight converter that handles the most common Markdown
  /// constructs. It intentionally does not cover every edge case -- the goal
  /// is a readable HTML export, not a fully spec-compliant renderer.
  static String _markdownToHtml(String md) {
    var html = md;

    // Escape HTML entities in the source so raw < and > do not break output.
    // We do this early so that the regex replacements below operate on safe
    // text, but we must be careful not to double-escape our own generated tags.
    html = _escapeHtml(html);

    // Fenced code blocks: ```lang\n...\n```
    html = html.replaceAllMapped(
      RegExp(r'```\w*\n([\s\S]*?)```'),
      (m) => '<pre><code>${m.group(1)!.trim()}</code></pre>',
    );

    // Inline code: `text`
    html = html.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) => '<code>${m.group(1)}</code>',
    );

    // Headings (must run before bold/italic so leading # is consumed).
    html = html.replaceAllMapped(
      RegExp(r'^####\s+(.+)$', multiLine: true),
      (m) => '<h4>${m.group(1)}</h4>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^###\s+(.+)$', multiLine: true),
      (m) => '<h3>${m.group(1)}</h3>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^##\s+(.+)$', multiLine: true),
      (m) => '<h2>${m.group(1)}</h2>',
    );
    html = html.replaceAllMapped(
      RegExp(r'^#\s+(.+)$', multiLine: true),
      (m) => '<h1>${m.group(1)}</h1>',
    );

    // Bold: **text**
    html = html.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => '<strong>${m.group(1)}</strong>',
    );

    // Italic: *text*
    html = html.replaceAllMapped(
      RegExp(r'\*(.+?)\*'),
      (m) => '<em>${m.group(1)}</em>',
    );

    // Images: ![alt](url)
    html = html.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'),
      (m) => '<img src="${m.group(2)}" alt="${m.group(1)}">',
    );

    // Links: [text](url)
    html = html.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => '<a href="${m.group(2)}">${m.group(1)}</a>',
    );

    // Blockquotes: > text
    html = html.replaceAllMapped(
      RegExp(r'^&gt;\s*(.+)$', multiLine: true),
      (m) => '<blockquote>${m.group(1)}</blockquote>',
    );
    // Collapse consecutive blockquotes.
    html = html.replaceAll(
      '</blockquote>\n<blockquote>',
      '\n',
    );

    // Unordered list items: - text or * text
    html = html.replaceAllMapped(
      RegExp(r'^[-*]\s+(.+)$', multiLine: true),
      (m) => '<li>${m.group(1)}</li>',
    );
    // Wrap consecutive <li> in <ul>.
    html = html.replaceAllMapped(
      RegExp(r'(<li>.*?</li>(\n<li>.*?</li>)*)'),
      (m) => '<ul>\n${m.group(0)}\n</ul>',
    );

    // Paragraphs: double newline separates blocks. Only apply to lines that
    // are not already wrapped in a block-level tag.
    final blockTags = RegExp(
      r'^<(h[1-6]|pre|blockquote|ul|ol|li|hr|article|div)',
    );
    final lines = html.split('\n\n');
    html = lines.map((block) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) return '';
      if (blockTags.hasMatch(trimmed)) return trimmed;
      // Preserve single newlines as <br> within a paragraph.
      return '<p>${trimmed.replaceAll('\n', '<br>')}</p>';
    }).join('\n');

    return html;
  }
}
