import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/export/pdf_export_service.dart';

/// A bottom sheet that provides print/share options for a single note.
///
/// Options include sharing the note as an HTML file (via the platform share
/// sheet) and copying the note content as formatted text to the clipboard.
class PrintPreviewSheet extends ConsumerStatefulWidget {
  /// The database record for the note to print.
  final Note note;

  /// The decrypted title (plain text).
  final String title;

  /// The decrypted content (plain text / markdown).
  final String content;

  const PrintPreviewSheet({
    super.key,
    required this.note,
    required this.title,
    required this.content,
  });

  @override
  ConsumerState<PrintPreviewSheet> createState() => _PrintPreviewSheetState();
}

class _PrintPreviewSheetState extends ConsumerState<PrintPreviewSheet> {
  bool _includeMetadata = true;
  bool _includeImages = false;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title.
            Text(
              l10n.printPreview,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),

            // Note preview card.
            _buildNotePreview(l10n, theme),
            const SizedBox(height: 16),

            // Options.
            SwitchListTile(
              value: _includeMetadata,
              onChanged: (v) => setState(() => _includeMetadata = v),
              title: Text(l10n.includeMetadata),
              subtitle: Text(
                l10n.tags,
                style: theme.textTheme.bodySmall,
              ),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile(
              value: _includeImages,
              onChanged: (v) => setState(() => _includeImages = v),
              title: Text(l10n.includeImages),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 12),

            // PDF and Print buttons.
            if (!kIsWeb) ...[
              Row(
                children: [
                  // Generate PDF.
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isExporting ? null : _generatePdf,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(l10n.generatePdf),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Print.
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isExporting ? null : _printPdf,
                      icon: _isExporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.print_outlined),
                      label: Text(l10n.printNote),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Action buttons.
            Row(
              children: [
                // Copy to clipboard.
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isExporting ? null : _copyToClipboard,
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.copyToClipboard),
                  ),
                ),
                const SizedBox(width: 12),
                // Share as HTML.
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isExporting ? null : _shareAsHtml,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.share_outlined),
                    label: Text(l10n.shareAsHtml),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotePreview(AppLocalizations l10n, ThemeData theme) {
    final previewText = widget.content.length > 200
        ? '${widget.content.substring(0, 200)}...'
        : widget.content;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title.isNotEmpty ? widget.title : l10n.untitled,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            previewText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Build the full HTML content for the note, optionally including metadata.
  String _buildHtmlContent() {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.title.isNotEmpty ? widget.title : l10n.untitled;
    final content = widget.content;

    // Build metadata section if requested.
    final metadataBuffer = StringBuffer();
    if (_includeMetadata) {
      metadataBuffer.writeln('<div class="meta">');
      metadataBuffer.writeln(
        '<p><strong>${l10n.versionHistory}:</strong> '
        '${widget.note.updatedAt.toLocal().toString().substring(0, 16)}</p>',
      );
      metadataBuffer.writeln(
        '<p><strong>${l10n.created}:</strong> '
        '${widget.note.createdAt.toLocal().toString().substring(0, 16)}</p>',
      );
      metadataBuffer.writeln('</div>');
      metadataBuffer.writeln('<hr>');
    }

    // Use ExportService to convert markdown content to HTML body.
    // We call the static helper via a simple regex-based conversion.
    // ExportService.exportAsHtml generates a full document but we need
    // just the metadata + content for our own template.
    final htmlBody = _markdownToHtml(content);

    return '<!DOCTYPE html>\n'
        '<html><head><meta charset="utf-8"><title>${_escapeHtml(title)}</title>\n'
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
        '.meta{font-size:0.85em;color:#666;margin-bottom:16px}\n'
        'hr{border:none;border-top:1px solid #eee;margin:16px 0}\n'
        '@media print{body{padding:0} .meta{display:block}}\n'
        '</style></head>\n'
        '<body>\n'
        '<h1>${_escapeHtml(title)}</h1>\n'
        '$metadataBuffer\n'
        '$htmlBody\n'
        '</body></html>';
  }

  /// Escape special HTML characters.
  static String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }

  /// Lightweight Markdown-to-HTML converter for the print preview.
  /// Handles headings, bold, italic, code, links, images, lists, and quotes.
  static String _markdownToHtml(String md) {
    var html = _escapeHtml(md);

    // Fenced code blocks.
    html = html.replaceAllMapped(
      RegExp(r'```\w*\n([\s\S]*?)```'),
      (m) => '<pre><code>${m.group(1)!.trim()}</code></pre>',
    );

    // Inline code.
    html = html.replaceAllMapped(
      RegExp(r'`([^`]+)`'),
      (m) => '<code>${m.group(1)}</code>',
    );

    // Headings.
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

    // Bold.
    html = html.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => '<strong>${m.group(1)}</strong>',
    );

    // Italic.
    html = html.replaceAllMapped(
      RegExp(r'\*(.+?)\*'),
      (m) => '<em>${m.group(1)}</em>',
    );

    // Images.
    html = html.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\(([^)]+)\)'),
      (m) => '<img src="${m.group(2)}" alt="${m.group(1)}">',
    );

    // Links.
    html = html.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => '<a href="${m.group(2)}">${m.group(1)}</a>',
    );

    // Blockquotes.
    html = html.replaceAllMapped(
      RegExp(r'^&gt;\s*(.+)$', multiLine: true),
      (m) => '<blockquote>${m.group(1)}</blockquote>',
    );
    html = html.replaceAll(
      '</blockquote>\n<blockquote>',
      '\n',
    );

    // Unordered list items.
    html = html.replaceAllMapped(
      RegExp(r'^[-*]\s+(.+)$', multiLine: true),
      (m) => '<li>${m.group(1)}</li>',
    );
    html = html.replaceAllMapped(
      RegExp(r'(<li>.*?</li>(\n<li>.*?</li>)*)'),
      (m) => '<ul>\n${m.group(0)}\n</ul>',
    );

    // Paragraphs.
    final blockTags =
        RegExp(r'^<(h[1-6]|pre|blockquote|ul|ol|li|hr|article|div)');
    final lines = html.split('\n\n');
    html = lines.map((block) {
      final trimmed = block.trim();
      if (trimmed.isEmpty) return '';
      if (blockTags.hasMatch(trimmed)) return trimmed;
      return '<p>${trimmed.replaceAll('\n', '<br>')}</p>';
    }).join('\n');

    return html;
  }

  /// Copy the note content (title + markdown) to the clipboard.
  void _copyToClipboard() {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.title.isNotEmpty ? widget.title : l10n.untitled;
    final text = StringBuffer()
      ..writeln(title)
      ..writeln()
      ..write(widget.content);

    Clipboard.setData(ClipboardData(text: text.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.copiedToClipboard)),
    );
  }

  /// Generate a PDF from the note content and share it.
  Future<void> _generatePdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    final l10n = AppLocalizations.of(context)!;

    try {
      final title = widget.title.isNotEmpty ? widget.title : l10n.untitled;
      await PdfExportService.sharePdf(title, widget.content);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.pdfGenerated)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// Open the system print dialog for the note content as PDF.
  Future<void> _printPdf() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    final l10n = AppLocalizations.of(context)!;

    try {
      final title = widget.title.isNotEmpty ? widget.title : l10n.untitled;
      await PdfExportService.printPdf(title, widget.content);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  /// Export the note as an HTML file and share it via the platform share sheet.
  Future<void> _shareAsHtml() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    final l10n = AppLocalizations.of(context)!;

    try {
      final htmlContent = _buildHtmlContent();
      final safeTitle = widget.title
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .replaceAll(' ', '_')
          .replaceAll(RegExp(r'_+'), '_');
      final suffix = widget.note.id.length >= 8
          ? widget.note.id.substring(0, 8)
          : widget.note.id;
      final filename = '${safeTitle}_$suffix.html';

      if (kIsWeb) {
        // On web, we cannot use share_plus file share. Just copy HTML.
        Clipboard.setData(ClipboardData(text: htmlContent));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.copiedToClipboard)),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(htmlContent);

      if (!mounted) return;

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: widget.title,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportedAsHtml)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }
}
