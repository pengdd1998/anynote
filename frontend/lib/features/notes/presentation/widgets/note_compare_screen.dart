import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/crypto/crypto_service.dart';
import '../../../../core/error/error.dart' show ErrorDisplay;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/error_state_widget.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../domain/text_diff.dart';

/// Decrypted note data used for note comparison.
class _NoteData {
  final String id;
  final String title;
  final String content;
  final DateTime updatedAt;

  const _NoteData({
    required this.id,
    required this.title,
    required this.content,
    required this.updatedAt,
  });
}

/// A paired diff line for side-by-side display.
class _DiffPair {
  final DiffLine? left;
  final DiffLine? right;

  const _DiffPair({this.left, this.right});
}

/// Screen that displays a dual-card comparison between two arbitrary notes.
///
/// Shows two side-by-side warm cards with synchronized scrolling and soft
/// color-coded diff highlighting (mint for additions, warm rose for removals).
class NoteCompareScreen extends ConsumerStatefulWidget {
  final String leftNoteId;
  final String rightNoteId;

  const NoteCompareScreen({
    super.key,
    required this.leftNoteId,
    required this.rightNoteId,
  });

  @override
  ConsumerState<NoteCompareScreen> createState() => _NoteCompareScreenState();
}

class _NoteCompareScreenState extends ConsumerState<NoteCompareScreen> {
  _NoteData? _leftNote;
  _NoteData? _rightNote;
  TextDiff? _diff;
  bool _isLoading = true;
  String? _errorMessage;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNotes();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final l10n = AppLocalizations.of(context)!;

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);

      final results = await Future.wait([
        db.notesDao.getNoteById(widget.leftNoteId),
        db.notesDao.getNoteById(widget.rightNoteId),
      ]);

      final leftRaw = results[0];
      final rightRaw = results[1];

      if (leftRaw == null || rightRaw == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = l10n.noteNotFound;
          });
        }
        return;
      }

      final left = await _decryptNote(leftRaw, crypto, l10n);
      final right = await _decryptNote(rightRaw, crypto, l10n);

      final diff = TextDiff.compute(left.content, right.content);

      if (mounted) {
        setState(() {
          _leftNote = left;
          _rightNote = right;
          _diff = diff;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ErrorDisplay.displayMessage(e, l10n);
          _isLoading = false;
        });
      }
    }
  }

  Future<_NoteData> _decryptNote(
    dynamic raw,
    CryptoService crypto,
    AppLocalizations l10n,
  ) async {
    String title = raw.plainTitle ?? l10n.untitled;
    String content = raw.plainContent ?? '';

    if (crypto.isUnlocked) {
      final decryptedContent =
          await crypto.decryptForItem(raw.id, raw.encryptedContent);
      if (decryptedContent != null) {
        content = decryptedContent;
      }

      if (raw.encryptedTitle != null) {
        final decryptedTitle =
            await crypto.decryptForItem(raw.id, raw.encryptedTitle!);
        if (decryptedTitle != null) {
          title = decryptedTitle;
        }
      }
    }

    return _NoteData(
      id: raw.id,
      title: title,
      content: content,
      updatedAt: raw.updatedAt,
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
        title: Text(l10n.noteDiff),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return ErrorStateWidget(
        message: _errorMessage!,
        onRetry: _loadNotes,
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final diff = _diff!;

    return Column(
      children: [
        // Summary stats row
        _buildStatsRow(l10n, diff),
        // Dual card content
        Expanded(child: _buildDualCards(diff)),
      ],
    );
  }

  Widget _buildStatsRow(AppLocalizations l10n, TextDiff diff) {
    if (diff.isIdentical) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.s4,
          AppSpacing.md,
          AppSpacing.s8,
        ),
        child: Text(
          l10n.noChanges,
          style: AppTextStyles.caption.copyWith(
            fontStyle: FontStyle.italic,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.darkTextTertiary
                : AppColors.lightTextTertiary,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.s4,
        AppSpacing.md,
        AppSpacing.s8,
      ),
      child: Row(
        children: [
          // Added stat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentMintBg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              l10n.linesAdded(diff.linesAdded),
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.accentMintText,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          // Removed stat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.lightErrorBg,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              l10n.linesRemoved(diff.linesRemoved),
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualCards(TextDiff diff) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCardBg : AppColors.lightCardBg;
    final left = _leftNote!;
    final right = _rightNote!;

    if (diff.lines.isEmpty) {
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
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left card
              Expanded(
                child: _buildCard(
                  title: left.title,
                  date: _formatDate(left.updatedAt),
                  accentColor: AppColors.error,
                  cardBg: cardBg,
                  isDark: isDark,
                  pairs: pairs,
                  side: _DiffSide.left,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              // Divider dot
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.lightDivider,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.s8),
              // Right card
              Expanded(
                child: _buildCard(
                  title: right.title,
                  date: _formatDate(right.updatedAt),
                  accentColor: AppColors.accentMintText,
                  cardBg: cardBg,
                  isDark: isDark,
                  pairs: pairs,
                  side: _DiffSide.right,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String date,
    required Color accentColor,
    required Color cardBg,
    required bool isDark,
    required List<_DiffPair> pairs,
    required _DiffSide side,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark
              ? AppColors.darkBorder.withAlpha(60)
              : AppColors.lightBorder.withAlpha(80),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.s12,
              AppSpacing.md,
              AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? AppColors.darkDivider.withAlpha(60)
                      : AppColors.lightDivider.withAlpha(80),
                  width: 0.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(150),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Text(
                    date,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Diff lines
          ...pairs.map((pair) => _buildPairLine(pair, side, isDark)),
          // Bottom padding
          const SizedBox(height: AppSpacing.s8),
        ],
      ),
    );
  }

  Widget _buildPairLine(_DiffPair pair, _DiffSide side, bool isDark) {
    final line = side == _DiffSide.left ? pair.left : pair.right;
    if (line == null) {
      // Placeholder for alignment.
      return const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 2,
        ),
        child: Text(
          ' ',
          style: TextStyle(
            fontSize: 13,
            fontFamily: 'RobotoMono',
            height: 1.5,
            color: Colors.transparent,
          ),
        ),
      );
    }

    final Color bg;
    final Color textColor;
    final Color? leftBorder;

    if (line.type == DiffType.unchanged) {
      bg = Colors.transparent;
      textColor = isDark
          ? AppColors.darkTextSecondary
          : AppColors.lightTextSecondary;
      leftBorder = null;
    } else if (line.type == DiffType.removed) {
      bg = isDark ? AppColors.error.withAlpha(20) : AppColors.lightErrorBg;
      textColor = isDark ? AppColors.error.withAlpha(200) : AppColors.error;
      leftBorder = AppColors.error.withAlpha(80);
    } else {
      bg = isDark ? AppColors.success.withAlpha(20) : AppColors.accentMintBg;
      textColor =
          isDark ? AppColors.success.withAlpha(200) : AppColors.accentMintText;
      leftBorder = AppColors.accentMintText.withAlpha(80);
    }

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: leftBorder != null
            ? Border(
                left: BorderSide(color: leftBorder, width: 2.5),
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 2,
      ),
      child: Text(
        line.text.isEmpty ? ' ' : line.text,
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'RobotoMono',
          height: 1.5,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${_pad(local.month)}-${_pad(local.day)} '
        '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}

/// Which side of the comparison we're rendering.
enum _DiffSide { left, right }
