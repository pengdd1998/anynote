import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';

/// Result returned when user selects a table size.
class TableSize {
  const TableSize(this.rows, this.cols);

  final int rows;
  final int cols;
}

/// A dialog that lets the user pick a table size via a draggable grid.
///
/// Displays a 10x10 grid where cells highlight as the user drags.
/// The top-left 2x2 area is always the minimum selection.
class TablePickerDialog extends StatefulWidget {
  const TablePickerDialog({super.key});

  @override
  State<TablePickerDialog> createState() => _TablePickerDialogState();
}

class _TablePickerDialogState extends State<TablePickerDialog> {
  static const int maxSize = 10;
  static const int minSize = 2;

  int _selectedRows = minSize;
  int _selectedCols = minSize;

  void _updateSelection(int row, int col) {
    setState(() {
      _selectedRows = row + 1;
      _selectedCols = col + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.insertTable),
      content: SizedBox(
        width: 280,
        height: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grid selector
            GestureDetector(
              onPanUpdate: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;

                final localPosition = box.globalToLocal(details.globalPosition);
                // Calculate grid cell from position (approximate)
                const cellSize = 24.0;
                const gridOffset = Offset(20, 20);
                final relativePos = localPosition - gridOffset;

                final col = (relativePos.dx / cellSize).floor();
                final row = (relativePos.dy / cellSize).floor();

                if (row >= 0 && row < maxSize && col >= 0 && col < maxSize) {
                  _updateSelection(row, col);
                }
              },
              onTapDown: (details) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;

                final localPosition = box.globalToLocal(details.globalPosition);
                const cellSize = 24.0;
                const gridOffset = Offset(20, 20);
                final relativePos = localPosition - gridOffset;

                final col = (relativePos.dx / cellSize).floor();
                final row = (relativePos.dy / cellSize).floor();

                if (row >= 0 && row < maxSize && col >= 0 && col < maxSize) {
                  _updateSelection(row, col);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF252220)
                      : const Color(0xFFFFFDFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF332E2B)
                        : const Color(0xFFF0E8DF),
                  ),
                ),
                child: _buildGrid(colorScheme, isDark),
              ),
            ),
            const SizedBox(height: 16),
            // Size indicator
            Text(
              '$_selectedCols x $_selectedRows',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.dragToSelectTableSize,
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    isDark ? const Color(0xFFA3988E) : const Color(0xFF6B5E54),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop<TableSize>(null),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop<TableSize>(
            TableSize(_selectedRows, _selectedCols),
          ),
          child: Text(AppLocalizations.of(context)!.insertLabel),
        ),
      ],
    );
  }

  Widget _buildGrid(ColorScheme colorScheme, bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxSize, (row) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(maxSize, (col) {
            final isSelected = row < _selectedRows && col < _selectedCols;
            final isValidSize = row < minSize && col < minSize;

            return Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : (isValidSize
                        ? (isDark
                            ? const Color(0xFF332E2B)
                            : const Color(0xFFE5DED5))
                        : Colors.transparent),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF332E2B)
                      : const Color(0xFFE5DED5),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      }),
    );
  }
}

/// Shows the table picker dialog and returns the selected size, or null if cancelled.
Future<TableSize?> showTablePickerDialog(BuildContext context) {
  return showDialog<TableSize>(
    context: context,
    builder: (context) => const TablePickerDialog(),
  );
}
