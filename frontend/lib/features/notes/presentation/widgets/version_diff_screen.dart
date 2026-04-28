import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/error/error.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../domain/text_diff.dart';

/// Decrypted version data used for diff comparison.
class _VersionData {
  final String id;
  final int versionNumber;
  final String title;
  final String content;
  final DateTime createdAt;

  const _VersionData({
    required this.id,
    required this.versionNumber,
    required this.title,
    required this.content,
    required this.createdAt,
  });
}

/// Screen that displays a unified diff between two note versions.
///
/// Shows color-coded lines (green for added, red for removed, default for
/// unchanged) with summary statistics and restore actions for both versions.
class VersionDiffScreen extends ConsumerStatefulWidget {
  final String noteId;
  final String olderVersionId;
  final String newerVersionId;

  const VersionDiffScreen({
    super.key,
    required this.noteId,
    required this.olderVersionId,
    required this.newerVersionId,
  });

  @override
  ConsumerState<VersionDiffScreen> createState() => _VersionDiffScreenState();
}

class _VersionDiffScreenState extends ConsumerState<VersionDiffScreen> {
  _VersionData? _olderVersion;
  _VersionData? _newerVersion;
  TextDiff? _diff;
  bool _isLoading = true;
  String? _errorMessage;

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
      final l10n = AppLocalizations.of(context)!;

      // Load both versions in parallel.
      final results = await Future.wait([
        db.noteVersionsDao.getVersionById(widget.olderVersionId),
        db.noteVersionsDao.getVersionById(widget.newerVersionId),
      ]);

      final olderRaw = results[0];
      final newerRaw = results[1];

      if (olderRaw == null || newerRaw == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = l10n.failedToLoadVersions;
          });
        }
        return;
      }

      // Decrypt both versions.
      final older = await _decryptVersion(olderRaw, crypto, l10n);
      final newer = await _decryptVersion(newerRaw, crypto, l10n);

      // Compute diff.
      final diff = TextDiff.compute(older.content, newer.content);

      if (mounted) {
        setState(() {
          _olderVersion = older;
          _newerVersion = newer;
          _diff = diff;
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

  Future<_VersionData> _decryptVersion(
    dynamic raw,
    CryptoService crypto,
    AppLocalizations l10n,
  ) async {
    String title = raw.plainTitle ?? l10n.untitled;
    String content = raw.plainContent ?? '';

    if (crypto.isUnlocked) {
      final decryptedContent =
          await crypto.decryptForItem(widget.noteId, raw.encryptedContent);
      if (decryptedContent != null) {
        content = decryptedContent;
      }

      if (raw.encryptedTitle != null) {
        final decryptedTitle =
            await crypto.decryptForItem(widget.noteId, raw.encryptedTitle!);
        if (decryptedTitle != null) {
          title = decryptedTitle;
        }
      }
    }

    return _VersionData(
      id: raw.id,
      versionNumber: raw.versionNumber,
      title: title,
      content: content,
      createdAt: raw.createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.versionDiff),
      ),
      body: _buildBody(),
      bottomNavigationBar: _diff != null && _olderVersion != null
          ? _buildBottomActions(l10n)
          : null,
    );
  }

  Widget _buildBody() {
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
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: _loadVersions,
                child: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final diff = _diff!;

    return Column(
      children: [
        // Header with version info and stats.
        _buildDiffHeader(l10n, diff),
        const Divider(height: 1),
        // Diff content.
        Expanded(child: _buildDiffContent(l10n, diff)),
      ],
    );
  }

  Widget _buildDiffHeader(AppLocalizations l10n, TextDiff diff) {
    final older = _olderVersion!;
    final newer = _newerVersion!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version comparison label.
          Text(
            '${l10n.versionNumber(older.versionNumber)} -> ${l10n.versionNumber(newer.versionNumber)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          // Dates.
          Text(
            '${_formatDate(older.createdAt)} -> ${_formatDate(newer.createdAt)}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          // Summary stats.
          if (diff.isIdentical)
            Text(
              l10n.noChanges,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Row(
              children: [
                _buildStatChip(
                  l10n.linesAdded(diff.linesAdded),
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildStatChip(
                  l10n.linesRemoved(diff.linesRemoved),
                  Colors.red,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDiffContent(AppLocalizations l10n, TextDiff diff) {
    if (diff.lines.isEmpty) {
      return Center(
        child: Text(
          l10n.noChanges,
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: diff.lines.length,
      itemBuilder: (context, index) {
        final line = diff.lines[index];
        return _buildDiffLine(line);
      },
    );
  }

  Widget _buildDiffLine(DiffLine line) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color backgroundColor;
    Color textColor;
    String prefix;

    switch (line.type) {
      case DiffType.added:
        backgroundColor = isDark
            ? Colors.green.shade900.withValues(alpha: 0.3)
            : Colors.green.shade50;
        textColor = isDark ? Colors.green.shade200 : Colors.green.shade900;
        prefix = '+';
        break;
      case DiffType.removed:
        backgroundColor = isDark
            ? Colors.red.shade900.withValues(alpha: 0.3)
            : Colors.red.shade50;
        textColor = isDark ? Colors.red.shade200 : Colors.red.shade900;
        prefix = '-';
        break;
      case DiffType.unchanged:
        backgroundColor = Colors.transparent;
        textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
        prefix = ' ';
        break;
    }

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Text(
        '$prefix ${line.text}',
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          height: 1.5,
          color: textColor,
        ),
      ),
    );
  }

  Widget? _buildBottomActions(AppLocalizations l10n) {
    final older = _olderVersion!;
    final newer = _newerVersion!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Restore older version.
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _confirmRestore(older, l10n),
                icon: const Icon(Icons.history, size: 18),
                label: Text(
                  l10n.versionNumber(older.versionNumber),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Restore newer version.
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _confirmRestore(newer, l10n),
                icon: const Icon(Icons.restore, size: 18),
                label: Text(
                  l10n.versionNumber(newer.versionNumber),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRestore(_VersionData version, AppLocalizations l10n) {
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
            onPressed: () {
              Navigator.pop(ctx);
              _restoreVersion(version, l10n);
            },
            child: Text(l10n.restore),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreVersion(
    _VersionData version,
    AppLocalizations l10n,
  ) async {
    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final noteId = widget.noteId;

      // Save current state as a new version before restoring.
      final currentNote = await db.notesDao.getNoteById(noteId);
      if (currentNote != null) {
        final count = await db.noteVersionsDao.getVersionCount(noteId);
        final newVersionId = const Object().hashCode.toString();

        await db.noteVersionsDao.createVersion(
          id: newVersionId,
          noteId: noteId,
          encryptedTitle: currentNote.encryptedTitle,
          plainTitle: currentNote.plainTitle,
          encryptedContent: currentNote.encryptedContent,
          plainContent: currentNote.plainContent,
          versionNumber: count + 1,
        );

        // Trim old versions (keep last 20).
        await db.noteVersionsDao.deleteVersionsOlderThan(noteId, 20);
      }

      // Encrypt the restored content for the note.
      String encryptedContent = version.content;
      String? encryptedTitle;

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
        AppSnackBar.info(context, message: l10n.versionRestored);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          message: l10n.failedToRestore(e.toString()),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)} '
        '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
