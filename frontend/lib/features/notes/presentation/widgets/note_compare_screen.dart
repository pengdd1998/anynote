import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../../../core/crypto/crypto_service.dart';
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

/// View mode for the note comparison screen.
enum _DiffViewMode { unified, sideBySide }

/// Screen that displays a diff between two arbitrary notes.
///
/// Shows color-coded lines (green for additions, red for deletions, gray for
/// unchanged) with summary statistics and a toggle between unified and
/// side-by-side view modes.
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
  _DiffViewMode _viewMode = _DiffViewMode.unified;

  // Controllers for synchronized scrolling in side-by-side mode.
  final ScrollController _leftScrollController = ScrollController();
  final ScrollController _rightScrollController = ScrollController();
  bool _isSyncingScroll = false;

  @override
  void initState() {
    super.initState();
    // Defer _loadNotes() until after the first frame so that
    // AppLocalizations.of(context) is available (inherited widgets are not
    // accessible during initState).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadNotes();
    });
    _setupSyncScroll();
  }

  @override
  void dispose() {
    _leftScrollController.dispose();
    _rightScrollController.dispose();
    super.dispose();
  }

  /// Set up bidirectional scroll synchronization for side-by-side mode.
  void _setupSyncScroll() {
    _leftScrollController.addListener(() {
      if (_isSyncingScroll || _viewMode != _DiffViewMode.sideBySide) return;
      _isSyncingScroll = true;
      _rightScrollController.jumpTo(_leftScrollController.offset);
      _isSyncingScroll = false;
    });
    _rightScrollController.addListener(() {
      if (_isSyncingScroll || _viewMode != _DiffViewMode.sideBySide) return;
      _isSyncingScroll = true;
      _leftScrollController.jumpTo(_rightScrollController.offset);
      _isSyncingScroll = false;
    });
  }

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final db = ref.read(databaseProvider);
      final crypto = ref.read(cryptoServiceProvider);
      final l10n = AppLocalizations.of(context)!;

      // Load both notes in parallel.
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

      // Decrypt both notes.
      final left = await _decryptNote(leftRaw, crypto, l10n);
      final right = await _decryptNote(rightRaw, crypto, l10n);

      // Compute diff (left = old, right = new).
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
          _errorMessage = e.toString();
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.noteDiff),
        actions: [
          if (_diff != null) ...[
            // View mode toggle.
            SegmentedButton<_DiffViewMode>(
              segments: [
                ButtonSegment(
                  value: _DiffViewMode.unified,
                  label: Text(
                    l10n.unifiedView,
                    style: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.list, size: 16),
                ),
                ButtonSegment(
                  value: _DiffViewMode.sideBySide,
                  label: Text(
                    l10n.sideBySideView,
                    style: const TextStyle(fontSize: 12),
                  ),
                  icon: const Icon(Icons.vertical_split, size: 16),
                ),
              ],
              selected: {_viewMode},
              onSelectionChanged: (selected) {
                setState(() => _viewMode = selected.first);
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: _buildBody(),
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
                onPressed: _loadNotes,
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
        // Header with note titles and stats.
        _buildDiffHeader(l10n, diff),
        const Divider(height: 1),
        // Diff content.
        Expanded(child: _buildDiffContent(l10n, diff)),
      ],
    );
  }

  Widget _buildDiffHeader(AppLocalizations l10n, TextDiff diff) {
    final left = _leftNote!;
    final right = _rightNote!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note title comparison with colored indicators.
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  left.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  right.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Dates.
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(left.updatedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _formatDate(right.updatedAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ],
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
            Text(
              l10n.linesChanged(diff.linesAdded, diff.linesRemoved),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
        ],
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

    switch (_viewMode) {
      case _DiffViewMode.unified:
        return _buildUnifiedView(diff);
      case _DiffViewMode.sideBySide:
        return _buildSideBySideView(diff);
    }
  }

  /// Unified diff view: a single list showing all diff lines.
  Widget _buildUnifiedView(TextDiff diff) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: diff.lines.length,
      itemBuilder: (context, index) {
        final line = diff.lines[index];
        return _buildDiffLine(line);
      },
    );
  }

  /// Side-by-side diff view: two synchronized panels.
  /// Left panel shows removed lines from the left note.
  /// Right panel shows added lines from the right note.
  Widget _buildSideBySideView(TextDiff diff) {
    // Split diff lines into left-only and right-only lists.
    final leftLines = <DiffLine>[];
    final rightLines = <DiffLine>[];

    for (final line in diff.lines) {
      switch (line.type) {
        case DiffType.unchanged:
          leftLines.add(line);
          rightLines.add(line);
        case DiffType.removed:
          leftLines.add(line);
        case DiffType.added:
          rightLines.add(line);
      }
    }

    // Pad the shorter list to ensure scroll sync alignment.
    final maxLen = leftLines.length > rightLines.length
        ? leftLines.length
        : rightLines.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left panel.
        Expanded(
          child: ListView.builder(
            controller: _leftScrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: maxLen,
            itemBuilder: (context, index) {
              if (index < leftLines.length) {
                return _buildDiffLine(leftLines[index], showPrefix: true);
              }
              // Empty spacer to keep alignment.
              return _buildEmptyLine();
            },
          ),
        ),
        Container(
          width: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        // Right panel.
        Expanded(
          child: ListView.builder(
            controller: _rightScrollController,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: maxLen,
            itemBuilder: (context, index) {
              if (index < rightLines.length) {
                return _buildDiffLine(rightLines[index], showPrefix: true);
              }
              return _buildEmptyLine();
            },
          ),
        ),
      ],
    );
  }

  /// Build an empty line placeholder for alignment in side-by-side mode.
  Widget _buildEmptyLine() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: const Text(
        '',
        style: TextStyle(fontSize: 13, fontFamily: 'monospace', height: 1.5),
      ),
    );
  }

  Widget _buildDiffLine(DiffLine line, {bool showPrefix = false}) {
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
      case DiffType.removed:
        backgroundColor = isDark
            ? Colors.red.shade900.withValues(alpha: 0.3)
            : Colors.red.shade50;
        textColor = isDark ? Colors.red.shade200 : Colors.red.shade900;
        prefix = '-';
      case DiffType.unchanged:
        backgroundColor = Colors.transparent;
        textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
        prefix = ' ';
    }

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 1),
      child: Text(
        '${showPrefix ? prefix : prefix} ${line.text}',
        style: TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
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
