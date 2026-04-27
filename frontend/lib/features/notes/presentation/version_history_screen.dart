import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/a11y_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/error/error.dart';

/// Screen that displays the version history of a note.
///
/// Users can:
/// - Tap a version to preview it in a dialog
/// - Long-press to select versions for comparison
/// - Compare two versions via the diff screen
/// - Restore any previous version
class VersionHistoryScreen extends ConsumerStatefulWidget {
  final String noteId;
  const VersionHistoryScreen({super.key, required this.noteId});

  @override
  ConsumerState<VersionHistoryScreen> createState() =>
      _VersionHistoryScreenState();
}

class _VersionHistoryScreenState extends ConsumerState<VersionHistoryScreen> {
  List<_DecryptedVersion> _versions = [];
  bool _isLoading = true;
  String? _errorMessage;

  /// IDs of versions currently selected for comparison.
  final Set<String> _selectedIds = {};

  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final rawVersions =
          await db.noteVersionsDao.getVersionsForNote(widget.noteId);
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;

      final decrypted = <_DecryptedVersion>[];
      for (final v in rawVersions) {
        String title = v.plainTitle ?? l10n.untitled;
        String content = v.plainContent ?? '';

        // Attempt decryption if crypto is unlocked.
        if (crypto.isUnlocked) {
          final decryptedContent =
              await crypto.decryptForItem(widget.noteId, v.encryptedContent);
          if (decryptedContent != null) {
            content = decryptedContent;
          }

          if (v.encryptedTitle != null) {
            final decryptedTitle =
                await crypto.decryptForItem(widget.noteId, v.encryptedTitle!);
            if (decryptedTitle != null) {
              title = decryptedTitle;
            }
          }
        }

        decrypted.add(
          _DecryptedVersion(
            id: v.id,
            noteId: v.noteId,
            versionNumber: v.versionNumber,
            title: title,
            content: content,
            encryptedContent: v.encryptedContent,
            encryptedTitle: v.encryptedTitle,
            createdAt: v.createdAt,
          ),
        );
      }

      if (mounted) {
        setState(() {
          _versions = decrypted;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final appError = ErrorMapper.map(e);
        setState(() {
          _errorMessage = ErrorDisplay.userMessage(appError);
          _isLoading = false;
        });
      }
    }
  }

  void _toggleSelection(String versionId) {
    setState(() {
      if (_selectedIds.contains(versionId)) {
        _selectedIds.remove(versionId);
      } else if (_selectedIds.length < 2) {
        _selectedIds.add(versionId);
      } else {
        // Already have 2 selected: replace the oldest selection.
        _selectedIds.remove(_selectedIds.first);
        _selectedIds.add(versionId);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedIds.clear();
    });
  }

  void _navigateToDiff() {
    if (_selectedIds.length != 2) return;

    // Find the selected versions and sort by version number (older first).
    final selected = _versions
        .where((v) => _selectedIds.contains(v.id))
        .toList()
      ..sort((a, b) => a.versionNumber.compareTo(b.versionNumber));

    final olderId = selected.first.id;
    final newerId = selected.last.id;

    context.push(
      '/notes/${widget.noteId}/diff?older=$olderId&newer=$newerId',
    );
  }

  void _showVersionPreview(_DecryptedVersion version) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(version.title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              version.content,
              style: const TextStyle(fontSize: 14, height: 1.6),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.close),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmRestore(version);
            },
            child: Text(l10n.restore),
          ),
        ],
      ),
    );
  }

  void _confirmRestore(_DecryptedVersion version) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.restoreVersion),
        content: Text(
          l10n.restoreVersionConfirm(version.versionNumber),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _restoreVersion(version);
            },
            child: Text(l10n.restore),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreVersion(_DecryptedVersion version) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final noteId = widget.noteId;

      // Save current state as a new version before restoring.
      final currentNote = await db.notesDao.getNoteById(noteId);
      if (currentNote != null) {
        final count = await db.noteVersionsDao.getVersionCount(noteId);
        final newVersionId = const Object().hashCode.toString();

        final String? versionPlainTitle = currentNote.plainTitle;
        final String? versionPlainContent = currentNote.plainContent;

        // Re-encrypt to store in the version snapshot.
        // The encryptedContent on the note is already encrypted with the noteId,
        // so we can reuse it directly for the version snapshot.
        await db.noteVersionsDao.createVersion(
          id: newVersionId,
          noteId: noteId,
          encryptedTitle: currentNote.encryptedTitle,
          plainTitle: versionPlainTitle,
          encryptedContent: currentNote.encryptedContent,
          plainContent: versionPlainContent,
          versionNumber: count + 1,
        );

        // Trim old versions (keep last 20).
        await db.noteVersionsDao.deleteVersionsOlderThan(noteId, 20);
      }

      // Now update the note with the restored version's content.
      // Re-encrypt the restored content for the note.
      String encryptedContent = version.encryptedContent;
      String? encryptedTitle = version.encryptedTitle;

      // If we have plaintext and crypto is available, re-encrypt to be safe.
      // Otherwise, use the existing encrypted blobs (they were encrypted with
      // the same noteId so they remain valid).
      if (crypto.isUnlocked && version.content.isNotEmpty) {
        encryptedContent = await crypto.encryptForItem(noteId, version.content);
      }
      if (crypto.isUnlocked && version.title != l10n.untitled) {
        encryptedTitle = await crypto.encryptForItem(noteId, version.title);
      }

      await db.notesDao.updateNote(
        id: noteId,
        encryptedContent: encryptedContent,
        encryptedTitle: encryptedTitle,
        plainContent: version.content,
        plainTitle: version.title == l10n.untitled ? null : version.title,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.versionRestored)),
        );
        // Reload versions to reflect the new snapshot.
        await _loadVersions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToRestore(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.versionHistory),
        actions: [
          if (_isSelecting)
            IconButton(
              onPressed: _clearSelection,
              icon: const Icon(Icons.close),
              tooltip: l10n.cancel,
            ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildCompareButton(l10n),
    );
  }

  Widget? _buildCompareButton(AppLocalizations l10n) {
    if (!_isSelecting) return null;

    final canCompare = _selectedIds.length == 2;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: FilledButton.icon(
          onPressed: canCompare ? _navigateToDiff : null,
          icon: const Icon(Icons.compare_arrows, size: 20),
          label: Text(
            canCompare ? l10n.compareVersions : l10n.selectTwoVersions,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.shade300,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.failedToLoadVersions,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadVersions,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_versions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.history, size: 64, color: Colors.grey.shade300),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.noVersionsYet,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.versionsSavedAutomatically,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVersions,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _versions.length,
        itemBuilder: (context, index) {
          final version = _versions[index];
          final isCurrent = index == 0;
          final isSelected = _selectedIds.contains(version.id);

          return A11yUtils.semanticCard(
            label: l10n.versionSemanticLabel(
              version.versionNumber,
              version.title,
              _formatDate(version.createdAt),
              isCurrent ? l10n.currentSuffix : '',
            ),
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: isSelected
                  ? Theme.of(context)
                      .colorScheme
                      .secondaryContainer
                      .withValues(alpha: 0.5)
                  : null,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isCurrent
                      ? Theme.of(context).colorScheme.primaryContainer
                      : isSelected
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                  child: Text(
                    'v${version.versionNumber}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isCurrent
                          ? Theme.of(context).colorScheme.onPrimaryContainer
                          : isSelected
                              ? Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                title: Text(
                  version.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text(
                  _buildSubtitle(version, l10n),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                trailing: _buildTrailing(isCurrent, isSelected),
                onTap: () {
                  if (_isSelecting) {
                    _toggleSelection(version.id);
                  } else {
                    _showVersionPreview(version);
                  }
                },
                onLongPress: () {
                  _toggleSelection(version.id);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  String _buildSubtitle(_DecryptedVersion version, AppLocalizations l10n) {
    final date = _formatDate(version.createdAt);
    final charCount = version.content.length;
    return '$date - $charCount chars';
  }

  Widget _buildTrailing(bool isCurrent, bool isSelected) {
    if (isCurrent) {
      final l10n = AppLocalizations.of(context)!;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          l10n.current,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (isSelected) {
      return Icon(
        Icons.check_circle,
        color: Theme.of(context).colorScheme.primary,
      );
    }

    if (_isSelecting) {
      return const ExcludeSemantics(child: Icon(Icons.radio_button_unchecked));
    }

    return const ExcludeSemantics(child: Icon(Icons.chevron_right));
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)} '
        '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

/// Decrypted version data for display.
class _DecryptedVersion {
  final String id;
  final String noteId;
  final int versionNumber;
  final String title;
  final String content;
  final String encryptedContent;
  final String? encryptedTitle;
  final DateTime createdAt;

  _DecryptedVersion({
    required this.id,
    required this.noteId,
    required this.versionNumber,
    required this.title,
    required this.content,
    required this.encryptedContent,
    required this.encryptedTitle,
    required this.createdAt,
  });
}
