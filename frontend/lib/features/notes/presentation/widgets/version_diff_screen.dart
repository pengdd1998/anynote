import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/error/error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../domain/note_envelope.dart';
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

/// A paired diff line for side-by-side display.
class _DiffPair {
  final DiffLine? left;
  final DiffLine? right;

  const _DiffPair({this.left, this.right});
}

/// Screen that displays a side-by-side diff between two note versions.
///
/// Shows paired content in two columns with soft color-coded backgrounds
/// (mint for added, warm rose for removed) and restore actions for both versions.
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

      final older = await _decryptVersion(olderRaw, crypto, l10n);
      final newer = await _decryptVersion(newerRaw, crypto, l10n);

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

  /// Build paired entries from unified diff lines for side-by-side display.
  List<_DiffPair> _buildPairs(TextDiff diff) {
    final pairs = <_DiffPair>[];
    int i = 0;
    while (i < diff.lines.length) {
      final line = diff.lines[i];
      if (line.type == DiffType.unchanged) {
        pairs.add(_DiffPair(left: line, right: line));
        i++;
      } else if (line.type == DiffType.removed) {
        if (i + 1 < diff.lines.length &&
            diff.lines[i + 1].type == DiffType.added) {
          pairs.add(_DiffPair(left: line, right: diff.lines[i + 1]));
          i += 2;
        } else {
          pairs.add(_DiffPair(left: line, right: null));
          i++;
        }
      } else {
        pairs.add(_DiffPair(left: null, right: line));
        i++;
      }
    }
    return pairs;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.versionDiff),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
      return _buildErrorState();
    }

    final l10n = AppLocalizations.of(context)!;
    final diff = _diff!;

    return Column(
      children: [
        _buildDiffHeader(l10n, diff),
        Expanded(child: _buildDiffContent(diff)),
      ],
    );
  }

  Widget _buildErrorState() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.lightErrorBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.error_outline,
                size: 28,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: _loadVersions,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiffHeader(AppLocalizations l10n, TextDiff diff) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final older = _olderVersion!;
    final newer = _newerVersion!;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Version pills
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkInputFill
                      : AppColors.lightInputFill,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  l10n.versionNumber(older.versionNumber),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
                child: Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  l10n.versionNumber(newer.versionNumber),
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${_formatDate(older.createdAt)} -> ${_formatDate(newer.createdAt)}',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
              ),
            ],
          ),
          // Summary stats
          if (!diff.isIdentical) ...[
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                _buildStatChip(
                  l10n.linesAdded(diff.linesAdded),
                  AppColors.accentMintBg,
                  AppColors.accentMintText,
                ),
                const SizedBox(width: AppSpacing.s8),
                _buildStatChip(
                  l10n.linesRemoved(diff.linesRemoved),
                  AppColors.lightErrorBg,
                  AppColors.error,
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              l10n.noChanges,
              style: AppTextStyles.caption.copyWith(
                fontStyle: FontStyle.italic,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _buildDiffContent(TextDiff diff) {
    if (diff.lines.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Text(
          AppLocalizations.of(context)!.noChanges,
          style: AppTextStyles.body.copyWith(
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
        ),
      );
    }

    final pairs = _buildPairs(diff);

    return Scrollbar(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: SizedBox(
          width: MediaQuery.of(context).size.width - AppSpacing.md * 2,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            itemCount: pairs.length,
            itemBuilder: (context, index) {
              return _buildDiffPair(pairs[index]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDiffPair(_DiffPair pair) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasLeft = pair.left != null && pair.left!.type != DiffType.unchanged;
    final hasRight =
        pair.right != null && pair.right!.type != DiffType.unchanged;

    final leftBg = pair.left?.type == DiffType.removed
        ? (isDark
            ? AppColors.error.withAlpha(25)
            : AppColors.lightErrorBg)
        : Colors.transparent;

    final rightBg = pair.right?.type == DiffType.added
        ? (isDark
            ? AppColors.success.withAlpha(25)
            : AppColors.accentMintBg)
        : Colors.transparent;

    final leftTextColor = pair.left?.type == DiffType.removed
        ? (isDark ? AppColors.error.withAlpha(200) : AppColors.error)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    final rightTextColor = pair.right?.type == DiffType.added
        ? (isDark ? AppColors.success.withAlpha(200) : AppColors.accentMintText)
        : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left column (older version)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: leftBg,
                border: hasLeft
                    ? Border(
                        left: BorderSide(
                          color: AppColors.error.withAlpha(80),
                          width: 3,
                        ),
                      )
                    : null,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: 2,
              ),
              child: pair.left != null
                  ? Text(
                      pair.left!.text.isEmpty ? ' ' : pair.left!.text,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'RobotoMono',
                        height: 1.5,
                        color: leftTextColor,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Subtle divider
          Container(
            width: 1,
            color: isDark
                ? AppColors.darkDivider.withAlpha(60)
                : AppColors.lightDivider.withAlpha(80),
          ),
          // Right column (newer version)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: rightBg,
                border: hasRight
                    ? Border(
                        left: BorderSide(
                          color: AppColors.accentMintText.withAlpha(80),
                          width: 3,
                        ),
                      )
                    : null,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: 2,
              ),
              child: pair.right != null
                  ? Text(
                      pair.right!.text.isEmpty ? ' ' : pair.right!.text,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'RobotoMono',
                        height: 1.5,
                        color: rightTextColor,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomActions(AppLocalizations l10n) {
    final older = _olderVersion!;
    final newer = _newerVersion!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.s8,
        ),
        child: Row(
          children: [
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
            const SizedBox(width: AppSpacing.s12),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(l10n.restoreVersion),
        content: Text(
          l10n.restoreVersionConfirm(version.versionNumber),
          style: AppTextStyles.body,
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

        await db.noteVersionsDao.deleteVersionsOlderThan(noteId, 20);
      }

      String encryptedContent = version.content;
      String? encryptedTitle;

      if (crypto.isUnlocked && version.content.isNotEmpty) {
        encryptedContent =
            await crypto.encryptForItem(noteId, version.content);
      }
      if (crypto.isUnlocked && version.title != l10n.untitled) {
        encryptedTitle = await crypto.encryptForItem(noteId, version.title);
      }

      await db.notesDao.updateNote(
        id: noteId,
        encryptedContent: encryptedContent,
        encryptedTitle: encryptedTitle,
        plainContent: storedContentToPlainText(version.content),
        plainTitle: version.title == l10n.untitled ? null : version.title,
      );

      if (mounted) {
        AppSnackBar.info(context, message: l10n.versionRestored);
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          message:
              l10n.failedToRestore(ErrorDisplay.displayMessage(e, l10n)),
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
