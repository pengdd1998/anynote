import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
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
          'title': note.plainTitle?.isNotEmpty == true ? note.plainTitle! : '',
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
/// Displays notes as soft pastel bubbles and links as subtle edges using a
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final graphAsync = ref.watch(localGraphDataProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.knowledgeGraph),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_outline),
            tooltip: l10n.suggestedLinks,
            onPressed: () => _showSuggestions(context),
          ),
          IconButton(
            icon: const Icon(Icons.scatter_plot_outlined),
            tooltip: l10n.orphanedNotes,
            onPressed: () => _showOrphanedNotes(context),
          ),
          IconButton(
            icon: const Icon(Icons.link),
            tooltip: l10n.manageLinks,
            onPressed: () => _showLinkManagement(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.resetView,
            onPressed: () {
              setState(() {});
            },
          ),
        ],
      ),
      body: graphAsync.when(
        data: (data) {
          _cachedData = data;

          if (data.nodes.isEmpty) {
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
                      Icons.account_tree_outlined,
                      size: 28,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.lightTextTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.noNotesYet,
                    style: AppTextStyles.title.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: Text(
                      l10n.graphEmptyHint,
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
                l10n.errorLoadingGraph,
                style: AppTextStyles.title.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
                child: Text(
                  '$e',
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
  late Map<String, int> _colorIndices;
  Offset _panOffset = Offset.zero;
  double _scale = 1.0;
  String? _hoveredNodeId;
  Timer? _simulationTimer;

  static const double _repulsion = 60000;
  static const double _springLength = 140;
  static const double _springK = 0.04;
  static const double _damping = 0.85;
  static const int _maxIterations = 300;

  Map<String, Offset> _velocities = {};

  @override
  void initState() {
    super.initState();
    _positions = {};
    _titles = {};
    _colorIndices = {};
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
    // Assign color indices deterministically based on title hash.
    _colorIndices = {
      for (int i = 0; i < widget.nodes.length; i++)
        widget.nodes[i]['id']!: i % _bubbleFillsLight.length,
    };
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

    double maxVelocity = 0;
    for (final node in widget.nodes) {
      final id = node['id']!;
      final force = forces[id]!;
      _velocities[id] = _velocities[id]! * _damping + force;
      final velocity = _velocities[id]!;
      maxVelocity = max(maxVelocity, velocity.distance);

      final newPos = _positions[id]! + velocity;

      final size = MediaQuery.of(context).size;
      _positions[id] = Offset(
        newPos.dx.clamp(60.0, size.width - 60),
        newPos.dy.clamp(60.0, size.height - 60),
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
        _scale = (_scale * details.scale).clamp(0.3, 4.0);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final untitled = AppLocalizations.of(context)?.untitled ?? 'Untitled';
    final localizedTitles = {
      for (final entry in _titles.entries)
        entry.key: entry.value.isEmpty ? untitled : entry.value,
    };

    return GestureDetector(
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onTapUp: (details) {
        final tapPos = details.localPosition;
        for (final node in widget.nodes) {
          final id = node['id']!;
          final pos = _positions[id];
          if (pos != null && (tapPos - _transformPoint(pos)).distance < 35) {
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
                (event.localPosition - _transformPoint(pos)).distance < 35) {
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
            titles: localizedTitles,
            colorIndices: _colorIndices,
            hoveredNodeId: _hoveredNodeId,
            scale: _scale,
            panOffset: _panOffset,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bubble color palette
// ---------------------------------------------------------------------------

const _bubbleFillsLight = <Color>[
  AppColors.accentPeachBg,
  AppColors.accentYellowBg,
  AppColors.accentMintBg,
  AppColors.accentPeachBg,
];

const _bubbleFillsDark = <Color>[
  Color(0xFF2A2545),
  Color(0xFF3B3420),
  Color(0xFF1E3828),
  Color(0xFF3B2E1E),
];

const _bubbleAccents = <Color>[
  AppColors.accentLavender,
  AppColors.accentYellow,
  AppColors.accentMint,
  AppColors.accentPeach,
];

const _bubbleTextColors = <Color>[
  AppColors.accentPeachText,
  AppColors.accentYellowText,
  AppColors.accentMintText,
  AppColors.accentPeachText,
];

// ---------------------------------------------------------------------------
// Graph Painter
// ---------------------------------------------------------------------------

/// CustomPainter that draws soft pastel node bubbles and subtle edges.
class _GraphPainter extends CustomPainter {
  final List<Map<String, String>> nodes;
  final List<Map<String, String>> edges;
  final Map<String, Offset> positions;
  final Map<String, String> titles;
  final Map<String, int> colorIndices;
  final String? hoveredNodeId;
  final double scale;
  final Offset panOffset;
  final bool isDark;

  _GraphPainter({
    required this.nodes,
    required this.edges,
    required this.positions,
    required this.titles,
    required this.colorIndices,
    required this.hoveredNodeId,
    required this.scale,
    required this.panOffset,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.translate(center.dx - panOffset.dx, center.dy - panOffset.dy);
    canvas.scale(scale);
    canvas.translate(-center.dx, -center.dy);

    _drawEdges(canvas);
    _drawNodes(canvas);
  }

  void _drawEdges(Canvas canvas) {
    final edgeColor = isDark
        ? AppColors.darkDivider.withAlpha(60)
        : AppColors.lightDivider.withAlpha(80);

    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final src = edge['sourceId'];
      final tgt = edge['targetId'];
      if (src == null || tgt == null) continue;
      final from = positions[src];
      final to = positions[tgt];
      if (from == null || to == null) continue;

      // Check if either endpoint is hovered to highlight the edge.
      final isHighlighted = src == hoveredNodeId || tgt == hoveredNodeId;

      if (isHighlighted) {
        final highlightPaint = Paint()
          ..color = (isDark ? AppColors.darkTextTertiary : AppColors.primary)
              .withAlpha(100)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(from, to, highlightPaint);
      } else {
        canvas.drawLine(from, to, edgePaint);
      }
    }
  }

  void _drawNodes(Canvas canvas) {
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (final node in nodes) {
      final id = node['id']!;
      final pos = positions[id];
      if (pos == null) continue;

      final isHovered = id == hoveredNodeId;
      final colorIdx = colorIndices[id] ?? 0;
      final nodeRadius = isHovered ? 30.0 : 24.0;

      final fillColor =
          isDark ? _bubbleFillsDark[colorIdx] : _bubbleFillsLight[colorIdx];
      final accentColor = _bubbleAccents[colorIdx];
      final textColor = _bubbleTextColors[colorIdx];

      // Soft shadow
      final shadowPaint = Paint()
        ..color = isDark ? AppColors.shadowDark : AppColors.shadowLight
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(
        pos + const Offset(0, 2),
        nodeRadius,
        shadowPaint,
      );

      // Filled bubble
      final fillPaint = Paint()..color = fillColor;
      canvas.drawCircle(pos, nodeRadius, fillPaint);

      // Accent border
      final borderAlpha = isHovered ? 200 : 80;
      final borderWidth = isHovered ? 2.5 : 1.5;
      final borderPaint = Paint()
        ..color = accentColor.withAlpha(borderAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      canvas.drawCircle(pos, nodeRadius, borderPaint);

      // Hover glow ring
      if (isHovered) {
        final glowPaint = Paint()
          ..color = accentColor.withAlpha(30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6;
        canvas.drawCircle(pos, nodeRadius + 4, glowPaint);
      }

      // Title label below bubble
      final label = titles[id] ?? id.substring(0, 4);
      final displayLabel =
          label.length > 14 ? '${label.substring(0, 11)}...' : label;

      final fontSize = isHovered ? 12.0 : 10.5;
      textPainter.text = TextSpan(
        text: displayLabel,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isHovered ? FontWeight.w600 : FontWeight.w500,
          color: isDark ? AppColors.darkTextPrimary : textColor,
          height: 1.2,
        ),
      );
      textPainter.layout();

      // Label background pill
      final labelBg = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: pos + Offset(0, nodeRadius + 14),
          width: textPainter.width + 10,
          height: textPainter.height + 6,
        ),
        const Radius.circular(8),
      );
      final bgPaint = Paint()
        ..color = isDark
            ? AppColors.darkCardBg.withAlpha(220)
            : AppColors.lightCardBg.withAlpha(230);
      canvas.drawRRect(labelBg, bgPaint);

      // Label text
      textPainter.paint(
        canvas,
        pos +
            Offset(
              -textPainter.width / 2,
              nodeRadius + 11,
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
      colorIndices != oldDelegate.colorIndices ||
      hoveredNodeId != oldDelegate.hoveredNodeId ||
      scale != oldDelegate.scale ||
      panOffset != oldDelegate.panOffset ||
      isDark != oldDelegate.isDark;
}
