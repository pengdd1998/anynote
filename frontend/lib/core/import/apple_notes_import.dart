import 'dart:io';

import 'import_models.dart';

/// Importer for Apple Notes HTML exports.
///
/// Apple Notes can export individual notes as HTML files with inline CSS.
/// Each file typically contains a `<title>` element with the note title and a
/// `<body>` with formatted content. This importer converts that HTML into
/// [ImportedNote] instances with basic Markdown formatting preserved.
///
/// The HTML-to-markdown conversion is regex-based (no external parser) and
/// handles the most common formatting tags. All other tags are stripped.
class AppleNotesImporter {
  /// Parse a single Apple Notes HTML export file into an [ImportedNote].
  ///
  /// Extracts the title from the `<title>` tag (falls back to the filename
  /// without extension), converts the HTML body to simple markdown, and uses
  /// the file's last-modified timestamp as [ImportedNote.createdAt].
  ///
  /// Tags are always empty (Apple Notes has no tags concept).
  ///
  /// Returns `null` if the file cannot be read or parsed.
  Future<ImportedNote?> parseHtmlFile(File file) async {
    try {
      if (!await file.exists()) return null;

      final html = await file.readAsString();
      final modified = await file.lastModified();

      final title = _extractTitle(html);
      final fallbackTitle = _filenameToTitle(file.path);
      final body = _convertHtmlToMarkdown(html);

      return ImportedNote(
        title: title.isNotEmpty ? title : fallbackTitle,
        body: body,
        tags: const [],
        createdAt: modified,
        sourcePath: file.path,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse all `.html` files in [dir] recursively.
  ///
  /// Files that fail to parse are silently skipped. Malformed HTML is handled
  /// gracefully on a per-file basis so one bad file does not abort the batch.
  Future<List<ImportedNote>> parseHtmlDirectory(Directory dir) async {
    final notes = <ImportedNote>[];

    try {
      if (!await dir.exists()) return notes;

      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.html')) {
          try {
            final note = await parseHtmlFile(entity);
            if (note != null) {
              notes.add(note);
            }
          } catch (_) {
            // Skip files that fail to parse.
          }
        }
      }
    } catch (_) {
      // Return whatever was collected before the error.
    }

    return notes;
  }

  // ---------------------------------------------------------------------------
  // HTML-to-markdown conversion (regex-based, no external parser)
  // ---------------------------------------------------------------------------

  /// Convert an Apple Notes HTML string to simple markdown.
  ///
  /// Handles:
  /// - `<h1>`-`<h6>` to `# ` - `###### `
  /// - `<b>` / `<strong>` to `**text**`
  /// - `<i>` / `<em>` to `*text*`
  /// - `<blockquote>` to `> `
  /// - `<a href="url">text</a>` to `[text](url)`
  /// - `<li>` (inside `<ul>`) to `- item`
  /// - `<li>` (inside `<ol>`) to `1. item`
  /// - `<p>` to double newline
  /// - `<br>` to newline
  /// - `<style>` and `<script>` blocks are removed entirely
  /// - All remaining tags are stripped via [_stripHtmlTags]
  static String _convertHtmlToMarkdown(String html) {
    // Extract just the <body> content if present, otherwise use full HTML.
    var body = html;
    final bodyMatch =
        RegExp(r'<body[^>]*>([\s\S]*?)</body>', dotAll: true).firstMatch(html);
    if (bodyMatch != null) {
      body = bodyMatch.group(1)!;
    }

    // Remove <style> and <script> blocks entirely.
    body = body.replaceAll(
      RegExp(r'<style[^>]*>[\s\S]*?</style>', dotAll: true),
      '',
    );
    body = body.replaceAll(
      RegExp(r'<script[^>]*>[\s\S]*?</script>', dotAll: true),
      '',
    );

    // Convert headings (h6 down to h1 to avoid nested replacements).
    for (var level = 6; level >= 1; level--) {
      final hashes = '#' * level;
      body = body.replaceAllMapped(
        RegExp('<h$level[^>]*>([\\s\\S]*?)</h$level>', dotAll: true),
        (m) => '\n$hashes ${_stripHtmlTags(m.group(1)!).trim()}\n',
      );
    }

    // Bold: <b> and <strong>
    body = body.replaceAllMapped(
      RegExp(r'<(b|strong)[^>]*>([\s\S]*?)</\1>', dotAll: true),
      (m) => '**${_stripHtmlTags(m.group(2)!).trim()}**',
    );

    // Italic: <i> and <em>
    body = body.replaceAllMapped(
      RegExp(r'<(i|em)[^>]*>([\s\S]*?)</\1>', dotAll: true),
      (m) => '*${_stripHtmlTags(m.group(2)!).trim()}*',
    );

    // Links: <a href="url">text</a> -> [text](url)
    body = body.replaceAllMapped(
      RegExp(r'<a\s+[^>]*href=["\x27]([^"\x27]*)["\x27][^>]*>([\s\S]*?)</a>',
          dotAll: true),
      (m) => '[${_stripHtmlTags(m.group(2)!).trim()}](${m.group(1)!})',
    );

    // Blockquotes: <blockquote>content</blockquote> -> > content
    body = body.replaceAllMapped(
      RegExp(r'<blockquote[^>]*>([\s\S]*?)</blockquote>', dotAll: true),
      (m) {
        final content = _stripHtmlTags(m.group(1)!).trim();
        final lines = content.split('\n');
        return lines.map((line) => '> ${line.trim()}').join('\n');
      },
    );

    // Ordered list items: <ol><li>...</li></ol> -> 1. item, 2. item, etc.
    body = body.replaceAllMapped(
      RegExp(r'<ol[^>]*>([\s\S]*?)</ol>', dotAll: true),
      (m) {
        var olContent = m.group(1)!;
        var index = 1;
        olContent = olContent.replaceAllMapped(
          RegExp(r'<li[^>]*>([\s\S]*?)</li>', dotAll: true),
          (li) => '${index++}. ${_stripHtmlTags(li.group(1)!).trim()}\n',
        );
        return olContent;
      },
    );

    // Unordered list items: <li> -> - item (remaining <li> outside <ol>)
    body = body.replaceAllMapped(
      RegExp(r'<li[^>]*>([\s\S]*?)</li>', dotAll: true),
      (m) => '- ${_stripHtmlTags(m.group(1)!).trim()}\n',
    );

    // Paragraphs: double newline.
    body = body.replaceAllMapped(
      RegExp(r'<p[^>]*>([\s\S]*?)</p>', dotAll: true),
      (m) => '\n${m.group(1)!}\n',
    );

    // Line breaks.
    body = body.replaceAll(
      RegExp(r'<br\s*/?\s*>', caseSensitive: false),
      '\n',
    );

    // Strip all remaining HTML tags.
    body = _stripHtmlTags(body);

    // Decode common HTML entities.
    body = _decodeHtmlEntities(body);

    // Clean up excessive whitespace.
    body = body
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

    return body;
  }

  /// Remove all HTML tags from a string, leaving only text content.
  static String _stripHtmlTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]+>'), '');
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Extract the `<title>` content from an HTML string.
  static String _extractTitle(String html) {
    final match =
        RegExp(r'<title[^>]*>([\s\S]*?)</title>', dotAll: true)
            .firstMatch(html);
    if (match == null) return '';
    return _decodeHtmlEntities(match.group(1)!.trim());
  }

  /// Decode common HTML entities to their character equivalents.
  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');
  }

  /// Derive a title from a file path by removing the extension.
  static String _filenameToTitle(String filePath) {
    final name = filePath.split(Platform.pathSeparator).last;
    final dotIndex = name.lastIndexOf('.');
    return dotIndex > 0 ? name.substring(0, dotIndex) : name;
  }
}
