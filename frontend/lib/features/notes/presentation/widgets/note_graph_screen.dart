import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../../main.dart';
import 'link_management_sheet.dart';
import 'link_suggestions_sheet.dart';
import 'orphaned_notes_sheet.dart';

/// Provider for local graph data using NoteLinksDao.
final localGraphDataProvider =
    FutureProvider.family<GraphData, void>((ref, _) async {
  final db = ref.read(databaseProvider);
  final notes = await db.notesDao.getAllNotes();
  final links = await db.noteLinksDao.getAllLinks();

  final nodes = notes
      .map(
        (note) => {
          'id': note.id,
          'title': note.plainTitle?.isNotEmpty == true
              ? note.plainTitle!
              : 'Untitled',
          'preview': note.plainContent ?? '',
        },
      )
      .toList();

  final edges = links
      .map(
        (link) => {
          'sourceId': link.sourceId,
          'targetId': link.targetId,
        },
      )
      .toList();

  return GraphData(
    nodes: nodes,
    edges: edges,
  );
});

/// Data structure for graph visualization.
class GraphData {
  final List<Map<String, String>> nodes;
  final List<Map<String, String>> edges;

  GraphData({
    required this.nodes,
    required this.edges,
  });
}

/// Knowledge graph visualization screen.
/// Displays notes as nodes and links as edges using a
/// force-directed layout drawn on a Canvas with pan/zoom support.
class NoteGraphScreen extends ConsumerStatefulWidget {
  const NoteGraphScreen({super.key});

  @override
  ConsumerState<NoteGraphScreen> createState() => _NoteGraphScreenState();
}

class _NoteGraphScreenState extends ConsumerState<NoteGraphScreen> {
  GraphData? _cachedData;

  void _showLinkManagement(BuildContext context) {
    if (_cachedData?.nodes.isEmpty ?? true) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => LinkManagementSheet(
        noteId: _cachedData!.nodes.first['id']!,
      ),
    );
  }

  void _showSuggestions(BuildContext context) {
    if (_cachedData?.nodes.isEmpty ?? true) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => LinkSuggestionsSheet(
        noteId: _cachedData!.nodes.first['id']!,
      ),
    );
  }

  void _showOrphanedNotes(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const OrphanedNotesSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final graphAsync = ref.watch(localGraphDataProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.knowledgeGraph),
        actions: [
          // Link suggestions
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: 'Suggested links',
            onPressed: () => _showSuggestions(context),
          ),
          // Orphaned notes
          IconButton(
            icon: const Icon(Icons.scatter_plot_outlined),
            tooltip: 'Orphaned notes',
            onPressed: () => _showOrphanedNotes(context),
          ),
          // Link management
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: 'Manage links',
            onPressed: () => _showLinkManagement(context),
          ),
          // Reset view
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset view',
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: graphAsync.when(
        data: (data) {
          // Cache data for use by AppBar actions
          _cachedData = data;

          if (data.nodes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notes yet',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create some notes and link them with [[wiki links]]',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }
          return Semantics(
            label: l10n.graphSummary(data.nodes.length, data.edges.length),
            child: ExcludeSemantics(
              child: _GraphCanvas(
                nodes: data.nodes,
                edges: data.edges,
                onNodeTap: (itemId) {
                  context.push('/notes/$itemId');
                },
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading graph',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                '$e',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Canvas widget that draws the interactive force-directed graph.
class _GraphCanvas extends StatefulWidget {
  final List<Map<String, String>> nodes;
  final List<Map<String, String>> edges;
  final ValueChanged<String> onNodeTap;

  const _GraphCanvas({
    required this.nodes,
    required this.edges,
    required this.onNodeTap,
  });

  @override
  State<_GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<_GraphCanvas>
    with TickerProviderStateMixin {
  late Map<String, Offset> _positions;
  late Map<String, String> _titles;
  Offset _panOffset = Offset.zero;
  double _scale = 1.0;
  String? _hoveredNodeId;
  Timer? _simulationTimer;

  // Force-directed layout parameters
  static const double _repulsion = 50000;
  static const double _springLength = 120;
  static const double _springK = 0.05;
  static const double _damping = 0.85;
  static const int _maxIterations = 300;

  Map<String, Offset> _velocities = {};

  @override
  void initState() {
    super.initState();
    _positions = {};
    _titles = {};
    _initializeData();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _initializeData() {
    _titles = {for (var n in widget.nodes) n['id']!: n['title']!};
    _velocities = {for (var n in widget.nodes) n['id']!: Offset.zero};
    _runForceLayout();
  }

  /// Simple force-directed layout algorithm.
  void _runForceLayout() {
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);

    // Initialize positions in a circle
    if (_positions.isEmpty) {
      final radius = min(size.width, size.height) * 0.35;
      for (int i = 0; i < widget.nodes.length; i++) {
        final id = widget.nodes[i]['id']!;
        final angle = (2 * pi * i) / widget.nodes.length;
        _positions[id] = Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        );
      }
    }

    // Run simulation iterations
    int iteration = 0;
    _simulationTimer?.cancel();
    _simulationTimer =
        Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (iteration >= _maxIterations || !mounted) {
        timer.cancel();
        return;
      }

      final hasMovement = _simulateStep();
      iteration++;

      if (hasMovement && mounted) {
        setState(() {});
      }
    });
  }

  bool _simulateStep() {
    final Map<String, Offset> forces = {};

    // Calculate repulsion between all node pairs
    for (final u in widget.nodes) {
      final uid = u['id']!;
      forces[uid] = Offset.zero;
      for (final v in widget.nodes) {
        if (u == v) continue;
        final vid = v['id']!;
        final uPos = _positions[uid]!;
        final vPos = _positions[vid]!;
        final delta = uPos - vPos;
        final dist = delta.distance;
        if (dist < 1) continue;
        final force = delta / dist * (_repulsion / (dist * dist));
        forces[uid] = forces[uid]! + force;
      }
    }

    // Calculate spring forces along edges
    for (final edge in widget.edges) {
      final srcId = edge['sourceId']!;
      final tgtId = edge['targetId']!;
      final srcPos = _positions[srcId];
      final tgtPos = _positions[tgtId];
      if (srcPos == null || tgtPos == null) continue;

      final delta = tgtPos - srcPos;
      final dist = delta.distance;
      final force = delta / dist * (dist - _springLength) * _springK;

      forces[srcId] = forces[srcId]! + force;
      forces[tgtId] = forces[tgtId]! - force;
    }

    // Apply forces and update positions
    double maxVelocity = 0;
    for (final node in widget.nodes) {
      final id = node['id']!;
      final force = forces[id]!;
      _velocities[id] = _velocities[id]! * _damping + force;
      final velocity = _velocities[id]!;
      maxVelocity = max(maxVelocity, velocity.distance);

      final newPos = _positions[id]! + velocity;

      // Keep within bounds
      final size = MediaQuery.of(context).size;
      _positions[id] = Offset(
        newPos.dx.clamp(50.0, size.width - 50),
        newPos.dy.clamp(50.0, size.height - 50),
      );
    }

    return maxVelocity > 0.1;
  }

  void _handleScaleStart(ScaleStartDetails details) {
    setState(() {
      _panOffset = details.localFocalPoint;
    });
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      if (details.scale != 1.0) {
        _scale = (_scale * details.scale).clamp(0.5, 3.0);
      }
      _panOffset = details.localFocalPoint;
    });
  }

  Offset _transformPoint(Offset point) {
    final size = MediaQuery.of(context).size;
    final center = size.center(Offset.zero);
    return (point - center) / _scale + center - _panOffset;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onTapUp: (details) {
        final tapPos = details.localPosition;
        for (final node in widget.nodes) {
          final id = node['id']!;
          final pos = _positions[id];
          if (pos != null && (tapPos - _transformPoint(pos)).distance < 30) {
            widget.onNodeTap(id);
            return;
          }
        }
      },
      child: MouseRegion(
        onHover: (event) {
          String? found;
          for (final node in widget.nodes) {
            final id = node['id']!;
            final pos = _positions[id];
            if (pos != null &&
                (event.localPosition - _transformPoint(pos)).distance < 30) {
              found = id;
              break;
            }
          }
          if (_hoveredNodeId != found) {
            setState(() {
              _hoveredNodeId = found;
            });
          }
        },
        child: CustomPaint(
          size: Size.infinite,
          painter: _GraphPainter(
            nodes: widget.nodes,
            edges: widget.edges,
            positions: _positions,
            titles: _titles,
            hoveredNodeId: _hoveredNodeId,
            scale: _scale,
            panOffset: _panOffset,
            nodeColor: Theme.of(context).colorScheme.primary,
            edgeColor: Theme.of(context).colorScheme.outlineVariant,
            labelStyle: Theme.of(context).textTheme.labelSmall!,
          ),
        ),
      ),
    );
  }
}

/// CustomPainter that draws nodes and edges.
class _GraphPainter extends CustomPainter {
  final List<Map<String, String>> nodes;
  final List<Map<String, String>> edges;
  final Map<String, Offset> positions;
  final Map<String, String> titles;
  final String? hoveredNodeId;
  final double scale;
  final Offset panOffset;
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
    this.hoveredNodeId,
    this.scale = 1.0,
    this.panOffset = Offset.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.translate(center.dx - panOffset.dx, center.dy - panOffset.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    // Draw edges.
    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.5;

    for (final edge in edges) {
      final src = edge['sourceId'];
      final tgt = edge['targetId'];
      if (src == null || tgt == null) continue;
      final from = positions[src];
      final to = positions[tgt];
      if (from != null && to != null) {
        canvas.drawLine(from, to, edgePaint);
      }
    }

    // Draw nodes.
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final node in nodes) {
      final id = node['id']!;
      final pos = positions[id];
      if (pos == null) continue;

      final isHovered = id == hoveredNodeId;
      final nodeRadius = isHovered ? 28.0 : 22.0;

      // Draw node shadow
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(pos + const Offset(2, 2), nodeRadius, shadowPaint);

      // Draw node circle
      final nodePaint = Paint()
        ..color = isHovered ? nodeColor.withValues(alpha: 0.9) : nodeColor;
      canvas.drawCircle(pos, nodeRadius, nodePaint);

      // Draw node border when hovered
      if (isHovered) {
        final borderPaint = Paint()
          ..color = nodeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(pos, nodeRadius + 3, borderPaint);
      }

      // Draw title label
      final label = titles[id] ?? id.substring(0, 4);
      final displayLabel =
          label.length > 15 ? '${label.substring(0, 12)}...' : label;

      textPainter.text = TextSpan(
        text: displayLabel,
        style: labelStyle.copyWith(
          color: Colors.white,
          fontSize: isHovered ? 12 : 10,
        ),
      );
      textPainter.layout();

      // Draw text background
      final textBg = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: pos + Offset(0, nodeRadius + 12),
          width: textPainter.width + 8,
          height: textPainter.height + 4,
        ),
        const Radius.circular(4),
      );
      final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.7);
      canvas.drawRRect(textBg, bgPaint);

      // Draw text
      textPainter.paint(
        canvas,
        pos +
            Offset(
              -textPainter.width / 2,
              nodeRadius + 10 - textPainter.height / 2,
            ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter oldDelegate) =>
      nodes != oldDelegate.nodes ||
      edges != oldDelegate.edges ||
      positions != oldDelegate.positions ||
      titles != oldDelegate.titles ||
      hoveredNodeId != oldDelegate.hoveredNodeId ||
      scale != oldDelegate.scale ||
      panOffset != oldDelegate.panOffset;
}
