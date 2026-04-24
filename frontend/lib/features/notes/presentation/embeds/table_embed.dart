import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

const String _tableEmbedKey = 'table';

/// Embed builder for table blocks in Quill editor.
///
/// Tables are stored as custom embeds with type 'table' and data containing
/// rows, cols, and a 2D array of cell contents.
class TableEmbedBuilder extends quill.EmbedBuilder {
  const TableEmbedBuilder();

  @override
  String get key => _tableEmbedKey;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final node = embedContext.node;
    final data = node.value.data;

    if (data == null) {
      return const SizedBox.shrink();
    }

    final tableData = _parseTableData(data);
    if (tableData == null) {
      return const SizedBox.shrink();
    }

    return TableBlockWidget(
      rows: tableData['rows'] as int? ?? 2,
      cols: tableData['cols'] as int? ?? 2,
      cells: tableData['cells'] as List<List<String>>? ?? [],
      controller: embedContext.controller,
      readOnly: embedContext.readOnly,
      textStyle: embedContext.textStyle,
    );
  }

  /// Parses table data from the embed node.
  ///
  /// Data can be either:
  /// 1. A JSON string: '{"rows":3,"cols":3,"cells":[["a","b"],["c","d"]]}'
  /// 2. A Map directly (already parsed)
  Map<String, dynamic>? _parseTableData(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

/// Interactive table widget with editable cells.
class TableBlockWidget extends StatefulWidget {
  const TableBlockWidget({
    super.key,
    required this.rows,
    required this.cols,
    required this.cells,
    required this.controller,
    required this.readOnly,
    required this.textStyle,
  });

  final int rows;
  final int cols;
  final List<List<String>> cells;
  final quill.QuillController controller;
  final bool readOnly;
  final TextStyle textStyle;

  @override
  State<TableBlockWidget> createState() => _TableBlockWidgetState();
}

class _TableBlockWidgetState extends State<TableBlockWidget> {
  late List<List<TextEditingController>> _cellControllers;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void didUpdateWidget(TableBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rows != widget.rows ||
        oldWidget.cols != widget.cols ||
        oldWidget.cells != widget.cells) {
      _disposeControllers();
      _initializeControllers();
    }
  }

  void _initializeControllers() {
    _cellControllers = List.generate(
      widget.rows,
      (row) => List.generate(
        widget.cols,
        (col) {
          final cellValue =
              row < widget.cells.length && col < widget.cells[row].length
                  ? widget.cells[row][col]
                  : '';
          return TextEditingController(text: cellValue);
        },
      ),
    );

    // Listen for changes to update the document
    for (var rowControllers in _cellControllers) {
      for (var cellController in rowControllers) {
        cellController.addListener(_onCellChanged);
      }
    }
  }

  void _disposeControllers() {
    for (var rowControllers in _cellControllers) {
      for (var controller in rowControllers) {
        controller.dispose();
      }
    }
    _cellControllers.clear();
  }

  void _onCellChanged() {
    // TODO: Implement proper document update when cell content changes
    // This requires tracking the embed position in the document
    // For now, cell edits are local until the document is saved/reloaded
    // The cells variable would be used to update the embed data:
    // final cells = _cellControllers.map((row) => row.map((c) => c.text).toList()).toList();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252220) : Colors.white,
        border: Border.all(
          color: isDark ? const Color(0xFF332E2B) : const Color(0xFFE5DED5),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Table(
            border: TableBorder.all(
              color: isDark ? const Color(0xFF332E2B) : const Color(0xFFE5DED5),
              width: 1,
            ),
            defaultColumnWidth: const FixedColumnWidth(120),
            children: List.generate(widget.rows, (row) {
              return TableRow(
                children: List.generate(widget.cols, (col) {
                  return _buildCell(row, col, isDark);
                }),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: _cellControllers[row][col],
        readOnly: widget.readOnly,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: widget.textStyle,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.all(8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF2A2623) : const Color(0xFFF5F1EB),
        ),
      ),
    );
  }
}

/// Creates a table embed data map that can be inserted into a Quill document.
Map<String, dynamic> createTableData({
  required int rows,
  required int cols,
  List<List<String>>? cells,
}) {
  return {
    'rows': rows,
    'cols': cols,
    'cells': cells ??
        List.generate(
          rows,
          (r) => List.generate(cols, (c) => ''),
        ),
  };
}

/// Inserts a table embed at the current cursor position in the Quill controller.
void insertTableEmbed({
  required quill.QuillController controller,
  required int rows,
  required int cols,
  List<List<String>>? cells,
}) {
  final tableData = createTableData(
    rows: rows,
    cols: cols,
    cells: cells,
  );

  // Create a custom block embed for the table
  final embed = quill.CustomBlockEmbed(
    _tableEmbedKey,
    jsonEncode(tableData),
  );

  // Insert at current position
  final index = controller.selection.baseOffset;
  final length = controller.selection.extentOffset - index;

  if (length > 0) {
    // Replace selected text with the embed
    controller.replaceText(
      index,
      length,
      embed,
      TextSelection.collapsed(offset: index + 1),
    );
  } else {
    // Insert the embed
    controller.document.insert(index, embed);
  }
}
