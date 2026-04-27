import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/import/import_models.dart';
import '../../../../core/import/markdown_import_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../domain/markdown_export_service.dart';

/// A bottom sheet for importing notes from Markdown files, ZIP archives,
/// and Obsidian vaults.
///
/// Provides three import modes:
///   - Select `.md` files for direct import.
///   - Select a `.zip` archive containing markdown files.
///   - Select an Obsidian vault folder (converts wiki links, copies images).
///
/// Import options (preserve dates, import tags, import properties) can be
/// toggled before starting the import. Progress is shown during the operation
/// and a result summary is displayed upon completion.
class ImportSheet extends ConsumerStatefulWidget {
  const ImportSheet({super.key});

  @override
  ConsumerState<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<ImportSheet> {
  bool _preserveDates = true;
  bool _importTags = true;
  bool _importProperties = true;
  bool _isImporting = false;
  double _progress = 0;
  String _currentFile = '';
  ImportResult? _result;

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

            Text(
              l10n.importNotes,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Source selection buttons.
            _buildSourceButtons(l10n, theme),
            const SizedBox(height: 16),

            // Import options.
            _buildImportOptions(l10n, theme),
            const SizedBox(height: 16),

            // Progress indicator.
            if (_isImporting) _buildProgressIndicator(l10n, theme),

            // Result summary.
            if (_result != null && !_isImporting)
              _buildResultSummary(l10n, theme),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Source buttons
  // ---------------------------------------------------------------------------

  Widget _buildSourceButtons(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.importOptions,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isImporting ? null : _onImportMarkdownFiles,
                icon: const Icon(Icons.description_outlined, size: 18),
                label: Text(l10n.importFromMarkdown),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isImporting ? null : _onImportZip,
                icon: const Icon(Icons.folder_zip_outlined, size: 18),
                label: Text(l10n.importFromZip),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isImporting ? null : _onImportObsidian,
                icon: const Icon(Icons.auto_awesome_outlined, size: 18),
                label: Text(l10n.importFromObsidian),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Import options toggles
  // ---------------------------------------------------------------------------

  Widget _buildImportOptions(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          value: _preserveDates,
          onChanged:
              _isImporting ? null : (v) => setState(() => _preserveDates = v),
          title: Text(l10n.preserveDates),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        SwitchListTile(
          value: _importTags,
          onChanged:
              _isImporting ? null : (v) => setState(() => _importTags = v),
          title: Text(l10n.importTags),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        SwitchListTile(
          value: _importProperties,
          onChanged: _isImporting
              ? null
              : (v) => setState(() => _importProperties = v),
          title: Text(l10n.importProperties),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Progress indicator
  // ---------------------------------------------------------------------------

  Widget _buildProgressIndicator(AppLocalizations l10n, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.importingNotes,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: _progress > 0 ? _progress : null),
        if (_currentFile.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            _currentFile,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Result summary
  // ---------------------------------------------------------------------------

  Widget _buildResultSummary(AppLocalizations l10n, ThemeData theme) {
    final imported = _result!.importedCount;
    final skipped = _result!.skippedCount;
    final hasErrors = _result!.hasErrors;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasErrors
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.15)
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasErrors
              ? theme.colorScheme.error.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasErrors ? Icons.warning_amber_outlined : Icons.check_circle,
                size: 20,
                color: hasErrors
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.importComplete(imported, skipped),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.notesImported(imported),
            style: theme.textTheme.bodyMedium,
          ),
          if (skipped > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${l10n.itemsSkipped}: $skipped',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (hasErrors) ...[
            const SizedBox(height: 4),
            ..._result!.errors.take(3).map(
                  (e) => Text(
                    e.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Import actions
  // ---------------------------------------------------------------------------

  /// Build the import options from current toggle states.
  ImportOptions _buildOptions({bool isObsidian = false, String? vaultPath}) {
    return ImportOptions(
      preserveDates: _preserveDates,
      importTags: _importTags,
      importProperties: _importProperties,
      isObsidianImport: isObsidian,
      obsidianVaultPath: vaultPath,
    );
  }

  /// Create a [MarkdownImportService] with the given options.
  MarkdownImportService _createService(ImportOptions options) {
    return MarkdownImportService(
      cryptoService: ref.read(cryptoServiceProvider),
      database: ref.read(databaseProvider),
      options: options,
    );
  }

  Future<void> _onImportMarkdownFiles() async {
    if (kIsWeb) {
      _showError(AppLocalizations.of(context)!.notSupportedOnWeb);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.selectMdFilesTitle,
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final filePaths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .where((p) {
      final lower = p.toLowerCase();
      return lower.endsWith('.md') || lower.endsWith('.markdown');
    }).toList();

    if (filePaths.isEmpty) {
      _showError(l10n.noFilesSelected);
      return;
    }

    setState(() {
      _isImporting = true;
      _progress = 0;
      _currentFile = '';
      _result = null;
    });

    try {
      final options = _buildOptions();
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);

      var importedCount = 0;
      var skippedCount = 0;
      final errors = <ImportError>[];

      for (var i = 0; i < filePaths.length; i++) {
        final path = filePaths[i];
        setState(() {
          _progress = (i + 1) / filePaths.length;
          _currentFile = path.split('/').last;
        });

        try {
          final file = File(path);
          final raw = await file.readAsString();
          if (raw.trim().isEmpty) {
            skippedCount++;
            continue;
          }

          // Use the shared parseYamlFrontmatter function.
          final importService = MarkdownImportService(
            cryptoService: crypto,
            database: db,
            options: options,
          );

          // Use parseDirectory on a temporary single-file approach: just
          // parse the content directly.
          final note = _parseRawContent(
            raw: raw,
            sourcePath: path,
            options: options,
          );
          if (note == null) {
            skippedCount++;
            continue;
          }

          // Save the note.
          final saveResult = await _saveSingleNote(
            service: importService,
            note: note,
          );
          if (saveResult) {
            importedCount++;
          } else {
            skippedCount++;
          }
        } catch (e) {
          errors.add(ImportError(filePath: path, message: e.toString()));
          skippedCount++;
        }
      }

      if (mounted) {
        setState(() {
          _isImporting = false;
          _result = ImportResult(
            importedCount: importedCount,
            skippedCount: skippedCount,
            errors: errors,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        _showError(
          AppLocalizations.of(context)!.importFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _onImportZip() async {
    if (kIsWeb) {
      _showError(AppLocalizations.of(context)!.notSupportedOnWeb);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n.selectMdFilesTitle,
      type: FileType.custom,
      allowedExtensions: ['zip'],
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) {
      _showError(l10n.noFilesSelected);
      return;
    }

    setState(() {
      _isImporting = true;
      _progress = 0;
      _currentFile = '';
      _result = null;
    });

    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      final options = _buildOptions();
      final service = _createService(options);

      setState(() {
        _progress = 0.5;
        _currentFile = filePath.split('/').last;
      });

      final importResult = await service.importFromZip(bytes);

      if (mounted) {
        setState(() {
          _isImporting = false;
          _progress = 1.0;
          _result = importResult;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        _showError(
          AppLocalizations.of(context)!.importFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _onImportObsidian() async {
    if (kIsWeb) {
      _showError(AppLocalizations.of(context)!.notSupportedOnWeb);
      return;
    }

    final vaultPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: AppLocalizations.of(context)!.selectMdFolderTitle,
    );
    if (vaultPath == null) return;

    setState(() {
      _isImporting = true;
      _progress = 0;
      _currentFile = '';
      _result = null;
    });

    try {
      final options = _buildOptions(isObsidian: true, vaultPath: vaultPath);
      final service = _createService(options);

      // Listen to progress.
      final progressSub = service.parseDirectory(Directory(vaultPath)).listen(
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress.progress * 0.5;
              _currentFile = progress.currentFile;
            });
          }
        },
      );
      await progressSub.cancel();

      final importResult =
          await service.importFromDirectory(Directory(vaultPath));

      if (mounted) {
        setState(() {
          _isImporting = false;
          _progress = 1.0;
          _result = importResult;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
        _showError(
          AppLocalizations.of(context)!.importFailed(e.toString()),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parse raw markdown content using the shared frontmatter parser.
  ImportedNote? _parseRawContent({
    required String raw,
    required String sourcePath,
    required ImportOptions options,
  }) {
    if (raw.trim().isEmpty) return null;

    final (:frontmatter, :body) = parseYamlFrontmatter(raw);

    // Title: frontmatter > filename without extension.
    String title;
    if (frontmatter['title'] is String) {
      title = frontmatter['title'] as String;
    } else {
      final name = sourcePath.split('/').last;
      title = name.endsWith('.md')
          ? name.substring(0, name.length - 3)
          : (name.endsWith('.markdown')
              ? name.substring(0, name.length - 9)
              : name);
    }

    // Date.
    DateTime createdAt = DateTime.now();
    final dateValue =
        frontmatter['date'] ?? frontmatter['created'] ?? frontmatter['updated'];
    if (options.preserveDates && dateValue is String) {
      createdAt = DateTime.tryParse(dateValue) ?? createdAt;
    }

    // Tags.
    List<String> tags = const [];
    if (options.importTags) {
      final rawTags = frontmatter['tags'];
      if (rawTags is List) {
        tags = rawTags.map((t) => t.toString()).toList();
      } else if (rawTags is String) {
        var tagStr = rawTags.trim();
        if (tagStr.startsWith('[') && tagStr.endsWith(']')) {
          tagStr = tagStr.substring(1, tagStr.length - 1);
        }
        tags = tagStr
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList();
      }
    }

    // Pinned.
    final isPinned =
        frontmatter['pinned'] == 'true' || frontmatter['pinned'] == true;

    return ImportedNote(
      title: title,
      body: body,
      tags: tags,
      createdAt: createdAt,
      sourcePath: sourcePath,
      frontmatter: Map<String, dynamic>.from(frontmatter),
      isPinned: isPinned,
    );
  }

  /// Save a single imported note using the service infrastructure.
  Future<bool> _saveSingleNote({
    required MarkdownImportService service,
    required ImportedNote note,
  }) async {
    try {
      // The importNotes method expects a list, so use a single-element list.
      final results = <ImportedNote>[note];
      await service.importNotes(results).drain<void>();
      return true;
    } catch (e) {
      debugPrint('[ImportSheet] failed to save imported note: $e');
      return false;
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
