import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/a11y_utils.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/error/error.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../../main.dart';

/// Screen that displays the version history of a note as a vertical timeline.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          version.title,
          style: AppTextStyles.title,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(
              version.content,
              style: AppTextStyles.body.copyWith(
                height: 1.7,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
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
        encryptedContent =
            await crypto.encryptForItem(noteId, version.content);
      }
      if (crypto.isUnlocked && version.title != l10n.untitled) {
        encryptedTitle =
            await crypto.encryptForItem(noteId, version.title);
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
        // Reload versions to reflect the new snapshot.
        await _loadVersions();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          message: l10n.failedToRestore(
              ErrorDisplay.displayMessage(e, l10n),),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.s8,
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorStateWidget(
        message: '${l10n.failedToLoadVersions}\n$_errorMessage',
        onRetry: _loadVersions,
      );
    }

    if (_versions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkInputFill
                    : AppColors.lightInputFill,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.history,
                size: 28,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.noVersionsYet,
              style: AppTextStyles.title.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                l10n.versionsSavedAutomatically,
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVersions,
      child: ListView.builder(
        padding: const EdgeInsets.only(
          top: AppSpacing.s8,
          bottom: 80,
        ),
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
            child: _buildTimelineItem(
              index,
              version,
              isCurrent: isCurrent,
              isSelected: isSelected,
              isDark: isDark,
              l10n: l10n,
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineItem(
    int index,
    _DecryptedVersion version, {
    required bool isCurrent,
    required bool isSelected,
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    final isFirst = index == 0;
    final primary = Theme.of(context).colorScheme.primary;

    final lineColor = isDark ? AppColors.darkDivider : AppColors.lightDivider;
    final cardBg = isDark ? AppColors.darkCardBg : AppColors.lightCardBg;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connector line from previous item.
          if (!isFirst)
            Padding(
              padding: const EdgeInsets.only(left: 11),
              child: Container(
                width: 2,
                height: AppSpacing.s8,
                color: lineColor,
              ),
            ),
          // Dot + card row.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline dot.
              SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isCurrent ? 12 : (isSelected ? 12 : 8),
                    height: isCurrent ? 12 : (isSelected ? 12 : 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? primary
                          : isSelected
                              ? primary.withAlpha(60)
                              : cardBg,
                      shape: BoxShape.circle,
                      border: isCurrent
                          ? null
                          : Border.all(
                              color:
                                  primary.withAlpha(isSelected ? 200 : 80),
                              width: 2,
                            ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: primary.withAlpha(40),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              // Version card.
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_isSelecting) {
                      _toggleSelection(version.id);
                    } else {
                      _showVersionPreview(version);
                    }
                  },
                  onLongPress: () => _toggleSelection(version.id),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primary.withAlpha(15)
                          : cardBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: isSelected
                          ? Border.all(
                              color: primary.withAlpha(80),
                              width: 1.5,
                            )
                          : null,
                      boxShadow: AppShadows.smOf(
                        Theme.of(context).brightness,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: version pill + trailing.
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? primary.withAlpha(20)
                                    : (isDark
                                        ? AppColors.darkInputFill
                                        : AppColors.lightInputFill),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                              child: Text(
                                'v${version.versionNumber}',
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isCurrent
                                      ? primary
                                      : (isDark
                                          ? AppColors.darkTextTertiary
                                          : AppColors.lightTextTertiary),
                                ),
                              ),
                            ),
                            const Spacer(),
                            _buildTrailing(isCurrent, isSelected),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        // Title.
                        Text(
                          version.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        // Timestamp + char count.
                        Text(
                          _buildSubtitle(version, l10n),
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _buildSubtitle(_DecryptedVersion version, AppLocalizations l10n) {
    final date = _formatDate(version.createdAt);
    final charCount = version.content.length;
    return '$date · $charCount chars';
  }

  Widget _buildTrailing(bool isCurrent, bool isSelected) {
    if (isCurrent) {
      final l10n = AppLocalizations.of(context)!;
      final primary = Theme.of(context).colorScheme.primary;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: primary.withAlpha(20),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          l10n.current,
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (isSelected) {
      return Icon(
        Icons.check_circle,
        size: 20,
        color: Theme.of(context).colorScheme.primary,
      );
    }

    if (_isSelecting) {
      return Icon(
        Icons.radio_button_unchecked,
        size: 20,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkTextTertiary
            : AppColors.lightTextTertiary,
      );
    }

    return const SizedBox.shrink();
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
