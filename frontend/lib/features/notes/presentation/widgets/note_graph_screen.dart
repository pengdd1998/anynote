import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/app_database.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import '../../providers/note_link_providers.dart';

/// Knowledge graph visualization screen.
/// Displays notes as nodes and links as edges using a simple
/// force-directed layout drawn on a Canvas.
class NoteGraphScreen extends ConsumerStatefulWidget {
  const NoteGraphScreen({super.key});

  @override
  ConsumerState<NoteGraphScreen> createState() => _NoteGraphScreenState();
}

class _NoteGraphScreenState extends ConsumerState<NoteGraphScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final graphAsync = ref.watch(noteGraphProvider);
    final db = ref.read(databaseProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.knowledgeGraph)),
      body: graphAsync.when(
        data: (data) {
          final nodes = (data['nodes'] as List?) ?? [];
          final edges = (data['edges'] as List?) ?? [];
          if (nodes.isEmpty) {
            return Center(
              child: Text(l10n.noBacklinks),
            );
          }
          return _GraphCanvas(
            nodes: nodes.cast<Map<String, dynamic>>(),
            edges: edges.cast<Map<String, dynamic>>(),
            db: db,
            onNodeTap: (itemId) {
              // Navigate to note editor.
              context.push('/notes/$itemId');
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

/// Canvas widget that draws the force-directed graph.
class _GraphCanvas extends StatefulWidget {
  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  final AppDatabase db;
  final ValueChanged<String> onNodeTap;

  const _GraphCanvas({
    required this.nodes,
    required this.edges,
    required this.db,
    required this.onNodeTap,
  });

  @override
  State<_GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<_GraphCanvas> {
  late Map<String, Offset> _positions;
  Map<String, String> _titles = {};

  @override
  void initState() {
    super.initState();
    _positions = {};
    _loadTitles();
  }

  Future<void> _loadTitles() async {
    final titles = <String, String>{};
    for (final node in widget.nodes) {
      final id = node['item_id'] as String;
      try {
        final note = await widget.db.notesDao.getNoteById(id);
        if (note != null &&
            note.plainTitle != null &&
            note.plainTitle!.isNotEmpty) {
          titles[id] = note.plainTitle!;
        } else {
          titles[id] = id.substring(0, 4);
        }
      } catch (_) {
        titles[id] = id.substring(0, 4);
      }
    }
    if (mounted) {
      setState(() {
        _titles = titles;
      });
    }
  }

  void _initializePositions(Size canvasSize) {
    final center = canvasSize.center(Offset.zero);
    final radius = min(canvasSize.width, canvasSize.height) * 0.35;
    for (int i = 0; i < widget.nodes.length; i++) {
      final id = widget.nodes[i]['item_id'] as String;
      final angle = (2 * pi * i) / widget.nodes.length;
      _positions[id] = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
        _initializePositions(canvasSize);
        return GestureDetector(
          onTapUp: (details) {
            final tapPos = details.localPosition;
            for (final node in widget.nodes) {
              final id = node['item_id'] as String;
              final pos = _positions[id];
              if (pos != null && (tapPos - pos).distance < 24) {
                widget.onNodeTap(id);
                return;
              }
            }
          },
          child: CustomPaint(
            size: Size.infinite,
            painter: _GraphPainter(
              nodes: widget.nodes,
              edges: widget.edges,
              positions: _positions,
              titles: _titles,
              nodeColor: Theme.of(context).colorScheme.primary,
              edgeColor: Theme.of(context).colorScheme.outlineVariant,
              labelStyle: Theme.of(context).textTheme.labelSmall!,
            ),
          ),
        );
      },
    );
  }
}

/// CustomPainter that draws nodes and edges.
class _GraphPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;
  final List<Map<String, dynamic>> edges;
  final Map<String, Offset> positions;
  final Map<String, String> titles;
  final Color nodeColor;
  final Color edgeColor;
  final TextStyle labelStyle;

  _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.positions,
    required this.titles,
    required this.nodeColor,
    required this.edgeColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw edges.
    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.5;

    for (final edge in edges) {
      final src = edge['source_id'] as String?;
      final tgt = edge['target_id'] as String?;
      if (src == null || tgt == null) continue;
      final from = positions[src];
      final to = positions[tgt];
      if (from != null && to != null) {
        canvas.drawLine(from, to, edgePaint);
      }
    }

    // Draw nodes.
    final nodePaint = Paint()..color = nodeColor;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final node in nodes) {
      final id = node['item_id'] as String;
      final pos = positions[id];
      if (pos == null) continue;

      canvas.drawCircle(pos, 20, nodePaint);

      // Draw title label, falling back to short ID.
      final label = titles[id] ?? id.substring(0, 4);
      textPainter.text = TextSpan(
        text: label,
        style: labelStyle.copyWith(color: Colors.white),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        pos - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      nodes != oldDelegate.nodes ||
      edges != oldDelegate.edges ||
      titles != oldDelegate.titles;
}
