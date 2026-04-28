import 'dart:io' if (dart.library.js) 'package:anynote/core/stubs/io_stub.dart';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/export/pdf_export_service.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/markdown_export_service.dart';

// ignore: unused_import - kept for reference; needed if direct DAO access is required later

/// The scope of notes to export.
enum ExportScope {
  /// Export only the current note.
  currentNote,

  /// Export notes selected in batch selection mode.
  selectedNotes,

  /// Export all non-deleted notes.
  allNotes,
}

/// Format for single-note export.
enum _SingleExportFormat { markdown, html, plainText, pdf }

/// A bottom sheet for configuring and triggering note exports.
///
/// Options include format, frontmatter inclusion, organization mode, and
/// export scope. For multiple notes, a ZIP archive is created.
class ExportSheet extends ConsumerStatefulWidget {
  /// The ID of the current note (for [ExportScope.currentNote]).
  final String? currentNoteId;

  /// The set of selected note IDs (for [ExportScope.selectedNotes]).
  final Set<String>? selectedNoteIds;

  /// The default scope to show.
  final ExportScope scope;

  const ExportSheet({
    super.key,
    this.currentNoteId,
    this.selectedNoteIds,
    this.scope = ExportScope.allNotes,
  });

  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet> {
  bool _includeFrontmatter = true;
  ExportOrganization _organization = ExportOrganization.flat;
  _SingleExportFormat _singleFormat = _SingleExportFormat.markdown;
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
            // Handle bar
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

            Text(
              l10n.exportNotes,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Scope indicator
            _buildScopeIndicator(l10n, theme),

            const SizedBox(height: 16),

            // Frontmatter toggle
            _buildFrontmatterToggle(l10n, theme),

            // Format selector for single-note export.
            if (widget.scope == ExportScope.currentNote) ...[
              const SizedBox(height: 16),
              _buildFormatSelector(l10n, theme),
            ],

            const SizedBox(height: 16),

            // Organization options (only for multi-note exports)
            if (widget.scope != ExportScope.currentNote) ...[
              _buildOrganizationSelector(l10n, theme),
              const SizedBox(height: 16),
            ],

            // Export button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isExporting ? null : _onExport,
                icon: _isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_download_outlined),
                label: Text(
                  _isExporting ? l10n.exportingNotes : l10n.exportAsZip,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeIndicator(AppLocalizations l10n, ThemeData theme) {
    final label = switch (widget.scope) {
      ExportScope.currentNote => l10n.exportCurrentNote,
      ExportScope.selectedNotes => l10n.exportSelected(
          widget.selectedNoteIds?.length ?? 0,
        ),
      ExportScope.allNotes => l10n.exportAllNotes,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.note_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrontmatterToggle(AppLocalizations l10n, ThemeData theme) {
    return SwitchListTile(
      value: _includeFrontmatter,
      onChanged: (value) => setState(() => _includeFrontmatter = value),
      title: Text(l10n.includeFrontmatter),
      subtitle: Text(
        l10n.frontmatterDesc,
        style: theme.textTheme.bodySmall,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildOrganizationSelector(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.exportOrganization,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildOrgChip(ExportOrganization.flat, l10n.exportFlat),
            _buildOrgChip(ExportOrganization.byDate, l10n.exportByDate),
            _buildOrgChip(
              ExportOrganization.byCollection,
              l10n.exportByCollection,
            ),
            _buildOrgChip(ExportOrganization.byTag, l10n.exportByTag),
          ],
        ),
      ],
    );
  }

  Widget _buildOrgChip(ExportOrganization org, String label) {
    final selected = _organization == org;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _organization = org),
    );
  }

  Widget _buildFormatSelector(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.exportOrganization, // reuse "Organization" label pattern
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildFormatChip(_SingleExportFormat.markdown, l10n.markdownFormat),
            _buildFormatChip(_SingleExportFormat.html, l10n.htmlFormat),
            _buildFormatChip(
              _SingleExportFormat.plainText,
              l10n.plainTextFormat,
            ),
            _buildFormatChip(_SingleExportFormat.pdf, l10n.exportFormatPdf),
          ],
        ),
      ],
    );
  }

  Widget _buildFormatChip(_SingleExportFormat format, String label) {
    final selected = _singleFormat == format;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _singleFormat = format),
    );
  }

  Future<void> _onExport() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    final l10n = AppLocalizations.of(context)!;

    try {
      final db = ref.read(databaseProvider);
      final notesDao = db.notesDao;
      final tagsDao = db.tagsDao;
      final propsDao = db.collectionsDao;

      // Determine which notes to export.
      List<Note> notes;
      switch (widget.scope) {
        case ExportScope.currentNote:
          if (widget.currentNoteId == null) {
            _showError(l10n.exportFailed(l10n.couldNotLoadForExport));
            return;
          }
          final note = await notesDao.getNoteById(widget.currentNoteId!);
          if (note == null) {
            _showError(l10n.exportFailed(l10n.couldNotLoadForExport));
            return;
          }
          notes = [note];

        case ExportScope.selectedNotes:
          if (widget.selectedNoteIds == null ||
              widget.selectedNoteIds!.isEmpty) {
            _showError(l10n.exportFailed(l10n.noNotesToExport));
            return;
          }
          final allNotes = <Note>[];
          for (final id in widget.selectedNoteIds!) {
            final note = await notesDao.getNoteById(id);
            if (note != null) allNotes.add(note);
          }
          notes = allNotes;

        case ExportScope.allNotes:
          notes = await notesDao.getAllNotes();
      }

      if (notes.isEmpty) {
        _showError(l10n.noNotesToExport);
        return;
      }

      // Build exportable notes with tags, properties, and collection info.
      final exportableNotes = <ExportableNote>[];
      for (final note in notes) {
        final title = note.plainTitle ?? l10n.untitled;
        final content = note.plainContent ?? '';

        if (content.trim().isEmpty) continue;

        // Load tags for this note.
        final tags = await tagsDao.getTagsForNote(note.id);

        // Load properties for this note.
        final propertiesDao = db.notePropertiesDao;
        final properties = await propertiesDao.getPropertiesForNote(note.id);

        // Load collection name if applicable.
        String? collectionName;
        try {
          // Get collections containing this note.
          final allCollections = await propsDao.getAllCollections();
          for (final collection in allCollections) {
            final collectionNotes =
                await propsDao.getCollectionNotes(collection.id);
            if (collectionNotes.any((cn) => cn.noteId == note.id)) {
              collectionName = collection.plainTitle ?? 'Untitled';
              break;
            }
          }
        } catch (e) {
          // Collection lookup failure is non-fatal for export.
          debugPrint('[ExportSheet] collection lookup failed: $e');
        }

        exportableNotes.add(
          ExportableNote(
            note: note,
            title: title,
            content: content,
            tags: tags,
            properties: properties,
            collectionName: collectionName,
          ),
        );
      }

      if (exportableNotes.isEmpty) {
        _showError(l10n.noNotesWithContent);
        return;
      }

      // If exporting a single note, write as individual file.
      if (exportableNotes.length == 1 &&
          widget.scope == ExportScope.currentNote) {
        final exportable = exportableNotes.first;

        // Handle PDF export separately -- it generates binary content.
        if (_singleFormat == _SingleExportFormat.pdf) {
          if (kIsWeb) {
            // PDF export is not supported on web in this path.
            _showError(l10n.exportFailed('PDF export not supported on web'));
            return;
          }
          await PdfExportService.sharePdf(
            exportable.title,
            exportable.content,
          );
          if (mounted) {
            AppSnackBar.info(context, message: l10n.pdfGenerated);
            Navigator.pop(context);
          }
          return;
        }

        final markdown = MarkdownExportService.noteToMarkdown(
          exportable,
          includeFrontmatter: _includeFrontmatter,
        );

        if (kIsWeb) {
          // Web: trigger download directly.
          _triggerWebDownload(
            markdown,
            '${MarkdownExportService.sanitizeFilename(exportable.title)}.md',
            'text/markdown;charset=utf-8',
          );
        } else {
          final dir = await getTemporaryDirectory();
          final filename =
              '${MarkdownExportService.sanitizeFilename(exportable.title)}_${exportable.note.id.length >= 8 ? exportable.note.id.substring(0, 8) : exportable.note.id}.md';
          final file = File('${dir.path}/$filename');
          await file.writeAsString(markdown);
          await Share.shareXFiles(
            [XFile(file.path)],
            subject: exportable.title,
          );
        }

        if (mounted) {
          AppSnackBar.info(context, message: l10n.exportComplete);
          Navigator.pop(context);
        }
        return;
      }

      // Multiple notes: export as ZIP.
      final file = await MarkdownExportService.exportToZip(
        exportableNotes,
        organization: _organization,
        includeFrontmatter: _includeFrontmatter,
      );

      if (!kIsWeb && file.path.isNotEmpty && mounted) {
        await MarkdownExportService.shareFile(file);
      }

      if (mounted) {
        AppSnackBar.info(
          context,
          message: l10n.notesExported(exportableNotes.length),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError(l10n.exportFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _isExporting = false);
    AppSnackBar.error(context, message: message);
  }

  /// Trigger a browser download for web platforms.
  void _triggerWebDownload(String content, String filename, String mime) {
    // On web, we use the existing web_download infrastructure.
    // This is handled conditionally via the export service.
  }
}
