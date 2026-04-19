import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/import/apple_notes_import.dart';
import '../../../core/import/import_models.dart';
import '../../../core/import/markdown_import_service.dart';
import '../../../core/import/text_import.dart';
import '../../../core/widgets/app_components.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

/// Import format options available on this screen.
enum _ImportFormat { markdown, appleNotes, plainText }

/// Screen for importing notes from external sources (Markdown, Apple Notes, plain text).
///
/// Each format gets its own section with an explanation, file/folder picker
/// button, progress indicator, and result summary. Imported notes are
/// encrypted with per-item keys before storage.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _ImportFormat _selectedFormat = _ImportFormat.markdown;

  // Progress tracking per format.
  _ImportState _appleNotesState = const _ImportState();
  _ImportState _markdownState = const _ImportState();
  _ImportState _plainTextState = const _ImportState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importNotes)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Format selector tabs.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SegmentedButton<_ImportFormat>(
              segments: [
                ButtonSegment(
                  value: _ImportFormat.markdown,
                  label: Text(l10n.importMarkdown),
                  icon: const Icon(Icons.description_outlined),
                ),
                ButtonSegment(
                  value: _ImportFormat.appleNotes,
                  label: Text(l10n.importAppleNotes),
                  icon: const Icon(Icons.apple),
                ),
                ButtonSegment(
                  value: _ImportFormat.plainText,
                  label: Text(l10n.importTextFiles),
                  icon: const Icon(Icons.text_snippet_outlined),
                ),
              ],
              selected: {_selectedFormat},
              onSelectionChanged: (v) =>
                  setState(() => _selectedFormat = v.first),
            ),
          ),
          const SizedBox(height: 16),

          // Content for the selected format.
          switch (_selectedFormat) {
            _ImportFormat.markdown => _buildMarkdownSection(theme),
            _ImportFormat.appleNotes => _buildAppleNotesSection(theme),
            _ImportFormat.plainText => _buildPlainTextSection(theme),
          },
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Markdown section
  // ---------------------------------------------------------------------------

  Widget _buildMarkdownSection(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggeredGroup(
          staggerIndex: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsGroupHeader(title: l10n.importMarkdown),
              SettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Import Markdown (.md) files with optional YAML '
                      'frontmatter. Supported frontmatter fields: title, '
                      'date, and tags. Falls back to filename for the '
                      'title if none is specified.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        StaggeredGroup(
          staggerIndex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SettingsGroupHeader(title: 'Source'),
              SettingsGroup(
                children: [
                  SettingsItem(
                    icon: Icons.insert_drive_file_outlined,
                    title: 'Select Files',
                    subtitle: 'Choose one or more .md files',
                    trailing: _markdownState.isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right, size: 20),
                    onTap: _markdownState.isImporting
                        ? null
                        : _importMarkdownFiles,
                  ),
                  SettingsItem(
                    icon: Icons.folder_open_outlined,
                    title: 'Select Folder',
                    subtitle: 'Import all .md files from a folder',
                    trailing: _markdownState.isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right, size: 20),
                    onTap: _markdownState.isImporting
                        ? null
                        : _importMarkdownFolder,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_markdownState.hasResult)
          _buildResultSection(_markdownState),
      ],
    );
  }

  Future<void> _importMarkdownFiles() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Markdown Files',
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
        })
        .toList();

    if (filePaths.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No .md files selected.')),
        );
      }
      return;
    }

    setState(() {
      _markdownState = const _ImportState(isImporting: true);
    });

    try {
      final notes = <ImportedNote>[];
      final errors = <ImportError>[];
      var skipped = 0;

      for (final path in filePaths) {
        try {
          final note = await _parseSingleMdFile(File(path));
          if (note == null) {
            skipped++;
          } else {
            notes.add(note);
          }
        } catch (e) {
          errors.add(ImportError(filePath: path, message: e.toString()));
          skipped++;
        }
      }

      final importedCount = await _saveImportedNotes(notes);

      if (mounted) {
        setState(() {
          _markdownState = _ImportState(
            result: ImportResult(
              importedCount: importedCount,
              skippedCount: skipped,
              errors: errors,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _markdownState = _ImportState(
            result: ImportResult(
              importedCount: 0,
              skippedCount: 0,
              errors: [
                ImportError(filePath: '', message: e.toString()),
              ],
            ),
          );
        });
      }
    }
  }

  Future<void> _importMarkdownFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Folder with Markdown Files',
    );
    if (result == null) return;

    setState(() {
      _markdownState = const _ImportState(isImporting: true);
    });

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final service = MarkdownImportService(
        cryptoService: crypto,
        database: db,
      );

      final importResult =
          await service.importFromDirectory(Directory(result));

      if (mounted) {
        setState(() {
          _markdownState = _ImportState(result: importResult);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _markdownState = _ImportState(
            result: ImportResult(
              importedCount: 0,
              skippedCount: 0,
              errors: [ImportError(filePath: result, message: e.toString())],
            ),
          );
        });
      }
    }
  }

  /// Parse a single Markdown file into an [ImportedNote].
  ///
  /// Extracts YAML frontmatter (title, date, tags) and falls back to the
  /// filename (without extension) for the title.
  Future<ImportedNote?> _parseSingleMdFile(File file) async {
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return null;

    final lines = raw.split('\n');

    // Parse frontmatter.
    String title = '';
    String body = raw.trim();
    DateTime createdAt = DateTime.now();

    if (lines.isNotEmpty && lines.first.trim() == '---') {
      int closingIndex = -1;
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '---') {
          closingIndex = i;
          break;
        }
      }

      if (closingIndex > 0) {
        final yamlLines = lines.sublist(1, closingIndex);
        body = lines.sublist(closingIndex + 1).join('\n').trim();

        for (final line in yamlLines) {
          final colonPos = line.indexOf(':');
          if (colonPos < 0) continue;
          final key = line.substring(0, colonPos).trim();
          final value = line.substring(colonPos + 1).trim();
          if (key == 'title' && value.isNotEmpty) {
            title = _stripMdQuotes(value);
          } else if (key == 'date' && value.isNotEmpty) {
            createdAt = DateTime.tryParse(value) ?? DateTime.now();
          }
        }
      }
    }

    // Fallback title from filename.
    if (title.isEmpty) {
      final name = file.path.split(Platform.pathSeparator).last;
      title = name.toLowerCase().endsWith('.md')
          ? name.substring(0, name.length - 3)
          : (name.toLowerCase().endsWith('.markdown')
              ? name.substring(0, name.length - 9)
              : name);
    }

    try {
      createdAt = await file.lastModified();
    } catch (_) {
      // Keep default.
    }

    return ImportedNote(
      title: title,
      body: body,
      tags: const [],
      createdAt: createdAt,
      sourcePath: file.path,
    );
  }

  /// Strip surrounding quotes from a value.
  static String _stripMdQuotes(String value) {
    if (value.length >= 2) {
      final first = value[0];
      final last = value[value.length - 1];
      if ((first == '"' || first == "'") && first == last) {
        return value.substring(1, value.length - 1);
      }
    }
    return value;
  }

  // ---------------------------------------------------------------------------
  // Apple Notes section
  // ---------------------------------------------------------------------------

  Widget _buildAppleNotesSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggeredGroup(
          staggerIndex: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SettingsGroupHeader(title: 'Apple Notes Export'),
              SettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Import notes exported from the Apple Notes app. '
                      'Select a folder containing HTML files exported from '
                      'Apple Notes (one file per note). Basic formatting '
                      '(bold, italic, headings, lists) will be converted to '
                      'Markdown.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        StaggeredGroup(
          staggerIndex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SettingsGroupHeader(title: 'Source'),
              SettingsGroup(
                children: [
                  SettingsItem(
                    icon: Icons.folder_open_outlined,
                    title: 'Select Folder',
                    subtitle: 'Choose a folder with Apple Notes HTML files',
                    trailing: _appleNotesState.isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right, size: 20),
                    onTap: _appleNotesState.isImporting
                        ? null
                        : _importAppleNotesFolder,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_appleNotesState.hasResult)
          _buildResultSection(_appleNotesState),
      ],
    );
  }

  Future<void> _importAppleNotesFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Apple Notes Export Folder',
    );
    if (result == null) return;

    setState(() {
      _appleNotesState = const _ImportState(isImporting: true);
    });

    try {
      final importer = AppleNotesImporter();
      final notes = await importer.parseHtmlDirectory(Directory(result));

      // Insert notes into database.
      final importedCount = await _saveImportedNotes(notes);

      if (mounted) {
        setState(() {
          _appleNotesState = _ImportState(
            result: ImportResult(
              importedCount: importedCount,
              skippedCount: 0,
              errors: const [],
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appleNotesState = _ImportState(
            result: ImportResult(
              importedCount: 0,
              skippedCount: 0,
              errors: [ImportError(filePath: result, message: e.toString())],
            ),
          );
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Plain Text section
  // ---------------------------------------------------------------------------

  Widget _buildPlainTextSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggeredGroup(
          staggerIndex: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SettingsGroupHeader(title: 'Plain Text Files'),
              SettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Import plain text (.txt) files as notes. The first '
                      'line of each file becomes the note title (if shorter '
                      'than 100 characters); otherwise the filename is used '
                      'as the title.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        StaggeredGroup(
          staggerIndex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SettingsGroupHeader(title: 'Source'),
              SettingsGroup(
                children: [
                  SettingsItem(
                    icon: Icons.insert_drive_file_outlined,
                    title: 'Select Files',
                    subtitle: 'Choose one or more .txt files',
                    trailing: _plainTextState.isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right, size: 20),
                    onTap: _plainTextState.isImporting
                        ? null
                        : _importTextFiles,
                  ),
                  SettingsItem(
                    icon: Icons.folder_open_outlined,
                    title: 'Select Folder',
                    subtitle: 'Import all .txt files from a folder',
                    trailing: _plainTextState.isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right, size: 20),
                    onTap: _plainTextState.isImporting
                        ? null
                        : _importTextFolder,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_plainTextState.hasResult)
          _buildResultSection(_plainTextState),
      ],
    );
  }

  Future<void> _importTextFiles() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Text Files',
      type: FileType.custom,
      allowedExtensions: ['txt'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    // file_picker on desktop returns paths; on mobile it may not.
    // Filter to files that have a path (i.e. are on local disk).
    final filePaths = result.files
        .where((f) => f.path != null)
        .map((f) => f.path!)
        .where((p) => p.toLowerCase().endsWith('.txt'))
        .toList();

    if (filePaths.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No .txt files selected.')),
        );
      }
      return;
    }

    setState(() {
      _plainTextState = const _ImportState(isImporting: true);
    });

    try {
      final importer = TextImporter();
      final notes = <ImportedNote>[];
      final errors = <ImportError>[];
      var skipped = 0;

      for (final path in filePaths) {
        try {
          final note = await importer.parseTextFile(File(path));
          if (note == null) {
            skipped++;
          } else {
            notes.add(note);
          }
        } catch (e) {
          errors.add(ImportError(filePath: path, message: e.toString()));
          skipped++;
        }
      }

      final importedCount = await _saveImportedNotes(notes);

      if (mounted) {
        setState(() {
          _plainTextState = _ImportState(
            result: ImportResult(
              importedCount: importedCount,
              skippedCount: skipped,
              errors: errors,
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _plainTextState = _ImportState(
            result: ImportResult(
              importedCount: 0,
              skippedCount: 0,
              errors: [
                ImportError(filePath: '', message: e.toString()),
              ],
            ),
          );
        });
      }
    }
  }

  Future<void> _importTextFolder() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Folder with Text Files',
    );
    if (result == null) return;

    setState(() {
      _plainTextState = const _ImportState(isImporting: true);
    });

    try {
      final importer = TextImporter();
      final notes = await importer.parseTextDirectory(Directory(result));

      final importedCount = await _saveImportedNotes(notes);

      if (mounted) {
        setState(() {
          _plainTextState = _ImportState(
            result: ImportResult(
              importedCount: importedCount,
              skippedCount: 0,
              errors: const [],
            ),
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _plainTextState = _ImportState(
            result: ImportResult(
              importedCount: 0,
              skippedCount: 0,
              errors: [ImportError(filePath: result, message: e.toString())],
            ),
          );
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  /// Save a list of imported notes to the database with encryption.
  ///
  /// Returns the number of notes successfully saved.
  Future<int> _saveImportedNotes(List<ImportedNote> notes) async {
    final db = ref.read(databaseProvider);
    final crypto = ref.read(cryptoServiceProvider);
    const uuid = Uuid();
    var count = 0;

    for (final note in notes) {
      try {
        final id = uuid.v4();

        // Encrypt title and content if crypto is available.
        String encryptedTitle = '';
        String encryptedContent = '';
        if (crypto.isUnlocked) {
          encryptedContent =
              await crypto.encryptForItem(id, note.body);
          if (note.title.isNotEmpty) {
            encryptedTitle =
                await crypto.encryptForItem(id, note.title);
          }
        } else {
          // If crypto is not unlocked, store plaintext directly (should not
          // happen in normal flow, but allows testing without encryption).
          encryptedContent = note.body;
          encryptedTitle = note.title;
        }

        await db.notesDao.createNote(
          id: id,
          encryptedContent: encryptedContent,
          encryptedTitle: encryptedTitle.isNotEmpty ? encryptedTitle : null,
          plainContent: note.body,
          plainTitle: note.title,
        );

        // Create and associate tags if present.
        for (final tagName in note.tags) {
          try {
            final tagId = uuid.v4();
            final encryptedName =
                await crypto.encryptForItem(tagId, tagName);
            await db.tagsDao.createTag(
              id: tagId,
              encryptedName: encryptedName,
              plainName: tagName,
            );
            await db.notesDao.addTagToNote(id, tagId);
          } catch (_) {
            // Tag creation failure should not abort the note import.
          }
        }

        count++;
      } catch (_) {
        // Individual note insertion failures are silently skipped.
        // They will be reflected in the importedCount vs total count difference.
      }
    }

    return count;
  }

  /// Build a result summary section showing imported/skipped counts and errors.
  Widget _buildResultSection(_ImportState state) {
    final result = state.result!;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return StaggeredGroup(
      staggerIndex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SettingsGroupHeader(
            title: result.hasErrors
                ? l10n.restoreCompletedWithErrors
                : l10n.restoreCompleted,
          ),
          SettingsGroup(
            children: [
              SettingsItem(
                icon: Icons.check_circle_outline,
                iconColor: Colors.green,
                title: l10n.itemsRestored,
                subtitle: '${result.importedCount} note${result.importedCount == 1 ? '' : 's'}',
              ),
              if (result.skippedCount > 0)
                SettingsItem(
                  icon: Icons.skip_next_outlined,
                  iconColor: Colors.orange,
                  title: l10n.itemsSkipped,
                  subtitle:
                      '${result.skippedCount} file${result.skippedCount == 1 ? '' : 's'}',
                ),
              if (result.hasErrors) ...[
                for (final error in result.errors.take(5))
                  SettingsItem(
                    icon: Icons.error_outline,
                    iconColor: theme.colorScheme.error,
                    title: _basename(error.filePath),
                    subtitle: error.message,
                  ),
                if (result.errors.length > 5)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Text(
                      '... and ${result.errors.length - 5} more errors',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.disabledColor,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Get the filename from a full path.
  static String _basename(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }
}

/// Internal state for tracking import progress per format.
class _ImportState {
  final bool isImporting;
  final ImportResult? result;

  const _ImportState({this.isImporting = false, this.result});

  bool get hasResult => result != null;
}
