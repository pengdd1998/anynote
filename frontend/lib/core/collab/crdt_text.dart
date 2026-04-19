/// A character in the RGA (Replicated Growable Array) sequence.
///
/// Each node represents a single character in the collaborative text.
/// Nodes are ordered by their insertion metadata (leftOriginId, rightOriginId,
/// siteId, clock) rather than a positional index, which allows concurrent
/// edits to converge deterministically.
class RGANode {
  /// Unique identifier: "{siteId}:{clock}".
  final String id;

  /// Left neighbor's ID at time of insertion, used for ordering.
  /// Empty string means this node is anchored at the start of the document.
  final String leftOriginId;

  /// Right neighbor's ID at time of insertion, used as a scan boundary.
  /// Empty string means no right neighbor was present (append to end).
  final String rightOriginId;

  /// Site ID of the agent that created this node.
  final String siteId;

  /// Lamport clock value at the time of insertion on the originating site.
  final int clock;

  /// The character value. Empty string means deleted (tombstone).
  String value;

  /// Whether this node has been logically deleted.
  bool isDeleted;

  RGANode({
    required this.id,
    required this.leftOriginId,
    required this.rightOriginId,
    required this.siteId,
    required this.clock,
    required this.value,
    this.isDeleted = false,
  });

  /// Serialize to a JSON-compatible map for network transmission or storage.
  Map<String, dynamic> toJson() => {
        'id': id,
        'left_origin': leftOriginId,
        'right_origin': rightOriginId,
        'site': siteId,
        'clock': clock,
        'value': value,
        'deleted': isDeleted,
      };

  /// Deserialize from a JSON map.
  factory RGANode.fromJson(Map<String, dynamic> json) => RGANode(
        id: json['id'] as String,
        leftOriginId: json['left_origin'] as String,
        rightOriginId: json['right_origin'] as String? ?? '',
        siteId: json['site'] as String,
        clock: json['clock'] as int,
        value: json['value'] as String,
        isDeleted: json['deleted'] as bool? ?? false,
      );

  @override
  String toString() =>
      'RGANode(id: $id, leftOrigin: $leftOriginId, rightOrigin: $rightOriginId, '
      'value: "$value", deleted: $isDeleted)';
}

/// RGA-based CRDT for collaborative text editing.
///
/// Implements the Replicated Growable Array algorithm where concurrent
/// insertions at the same logical position are ordered deterministically
/// by siteId. All operations commute, guaranteeing eventual consistency
/// across replicas.
///
/// The insertion scan uses [leftOriginId] as the anchor and [rightOriginId]
/// as a boundary. Nodes sharing the same [leftOriginId] are ordered by
/// siteId (lexicographic comparison). The [merge] method ensures causal
/// ordering by deferring insertions whose leftOrigin has not yet been
/// integrated.
class CRDTText {
  /// Unique site identifier for this replica.
  final String siteId;

  /// Lamport clock -- monotonically increasing counter for operation ordering.
  int _clock = 0;

  /// Ordered list of character nodes representing the document.
  final List<RGANode> _nodes = [];

  /// Map from node ID to node for O(1) lookup.
  final Map<String, RGANode> _nodeMap = {};

  /// Map from node ID to its index in [_nodes] for O(1) position lookup.
  final Map<String, int> _indexMap = {};

  /// Sentinel ID for the document start (leftOriginId of the first character).
  static const String _startSentinel = '';

  CRDTText(this.siteId);

  /// Current Lamport clock value.
  int get clock => _clock;

  /// The current text content with tombstones excluded.
  String get text =>
      _nodes.where((n) => !n.isDeleted).map((n) => n.value).join();

  /// Number of nodes (including tombstones).
  int get nodeCount => _nodes.length;

  /// Whether the document contains any nodes.
  bool get isEmpty => _nodes.isEmpty;

  /// Insert [chars] at visible [index] (local operation).
  ///
  /// Returns the list of newly created nodes so the caller can
  /// broadcast them to remote sites.
  List<RGANode> localInsert(int index, String chars) {
    if (chars.isEmpty) return [];

    final newNodes = <RGANode>[];

    // Find the left neighbor (node at index-1 in visible sequence)
    // and the right neighbor (node at index in visible sequence).
    var leftId = _findLeftNeighborId(index);
    final rightId = _findRightNeighborId(index);

    for (var i = 0; i < chars.length; i++) {
      _clock++;
      final node = RGANode(
        id: '$siteId:$_clock',
        leftOriginId: leftId,
        rightOriginId: rightId,
        siteId: siteId,
        clock: _clock,
        value: chars[i],
      );
      _insertNode(node);
      newNodes.add(node);
      // Chain: each subsequent character is anchored after the previous one.
      leftId = node.id;
    }

    return newNodes;
  }

  /// Delete [length] characters starting at visible [index] (local operation).
  ///
  /// Marks the nodes as tombstones. Returns the list of tombstoned node IDs
  /// so the caller can broadcast deletions to remote sites.
  List<String> localDelete(int index, int length) {
    final deletedIds = <String>[];
    final visibleNodes = _nodes.where((n) => !n.isDeleted).toList();

    for (var i = 0; i < length && (index + i) < visibleNodes.length; i++) {
      final node = visibleNodes[index + i];
      node.isDeleted = true;
      node.value = '';
      deletedIds.add(node.id);
    }

    return deletedIds;
  }

  /// Apply a remote insert operation.
  ///
  /// Inserts the node at the correct position using RGA ordering rules.
  /// Returns true if the node was successfully inserted, false if its
  /// leftOrigin has not yet been integrated (caller should retry later).
  bool remoteInsert(RGANode node) {
    if (_nodeMap.containsKey(node.id)) return true; // Already applied.

    // Ensure the leftOrigin is already in the document (causal dependency).
    if (node.leftOriginId.isNotEmpty && !_nodeMap.containsKey(node.leftOriginId)) {
      return false; // Cannot insert yet; leftOrigin not found.
    }

    // Ensure the rightOrigin is already in the document if specified.
    if (node.rightOriginId.isNotEmpty && !_nodeMap.containsKey(node.rightOriginId)) {
      return false; // Cannot insert yet; rightOrigin not found.
    }

    final copy = _copyNode(node);
    final insertIndex = _computeInsertIndex(copy);
    _insertAtIndex(insertIndex, copy);
    _updateClock(copy.clock);
    return true;
  }

  /// Apply a remote delete operation by node ID.
  void remoteDelete(String nodeId) {
    final node = _nodeMap[nodeId];
    if (node != null) {
      node.isDeleted = true;
      node.value = '';
    }
  }

  /// Get all operations (for full-document sync).
  List<RGANode> getOperations() => List.unmodifiable(_nodes);

  /// Get all operations newer than [sinceClock].
  ///
  /// Used for incremental sync: the caller sends its last-known clock
  /// and receives only operations it has not yet seen.
  List<RGANode> getOpsSince(int sinceClock) =>
      _nodes.where((n) => n.clock > sinceClock).toList();

  /// Merge operations from a remote site.
  ///
  /// Processes remote nodes in causal order: a node is only integrated
  /// after its leftOrigin and rightOrigin dependencies are satisfied.
  /// This ensures deterministic convergence regardless of the order in
  /// which operations arrive.
  void merge(List<RGANode> remoteNodes) {
    // Build a queue of nodes to process. We use a fixed-point loop:
    // keep trying to insert deferred nodes until no more progress is made.
    final pending = <RGANode>[];

    for (final remoteNode in remoteNodes) {
      final existing = _nodeMap[remoteNode.id];
      if (existing != null) {
        // Already known; apply any newer deletion.
        if (remoteNode.isDeleted && !existing.isDeleted) {
          existing.isDeleted = true;
          existing.value = '';
        }
        continue;
      }
      pending.add(remoteNode);
    }

    // Process pending nodes until no more can be integrated.
    var madeProgress = true;
    while (madeProgress && pending.isNotEmpty) {
      madeProgress = false;
      final stillPending = <RGANode>[];

      for (final node in pending) {
        if (_nodeMap.containsKey(node.id)) {
          // Integrated as a dependency of a previous node.
          if (node.isDeleted) {
            final existing = _nodeMap[node.id]!;
            if (!existing.isDeleted) {
              existing.isDeleted = true;
              existing.value = '';
            }
          }
          madeProgress = true;
          continue;
        }

        final inserted = remoteInsert(node);
        if (inserted) {
          if (node.isDeleted) {
            // The node was integrated but should be a tombstone.
            // remoteInsert already added it; ensure it's deleted.
            final n = _nodeMap[node.id]!;
            n.isDeleted = true;
            n.value = '';
          }
          madeProgress = true;
        } else {
          stillPending.add(node);
        }
      }

      pending.clear();
      pending.addAll(stillPending);
    }

    // Any remaining pending nodes have unsatisfied dependencies.
    // In a well-formed document stream, this should not happen.
    // As a last resort, append them at the end.
    for (final node in pending) {
      if (!_nodeMap.containsKey(node.id)) {
        final copy = _copyNode(node);
        _insertAtIndex(_nodes.length, copy);
        _updateClock(copy.clock);
        if (copy.isDeleted) {
          final n = _nodeMap[copy.id]!;
          n.isDeleted = true;
          n.value = '';
        }
      }
    }
  }

  /// Serialize the full document to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'site_id': siteId,
        'clock': _clock,
        'nodes': _nodes.map((n) => n.toJson()).toList(),
      };

  /// Deserialize a full document from a JSON map.
  factory CRDTText.fromJson(Map<String, dynamic> json) {
    final crdt = CRDTText(json['site_id'] as String);
    crdt._clock = json['clock'] as int;
    for (final n in json['nodes'] as List) {
      final node = RGANode.fromJson(n as Map<String, dynamic>);
      crdt._nodes.add(node);
      crdt._nodeMap[node.id] = node;
    }
    crdt._rebuildIndexMap();
    return crdt;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Create a defensive copy of a remote node before storing it locally.
  /// This prevents shared mutable state when the same RGANode reference is
  /// passed to multiple CRDTText instances (e.g. in tests).
  RGANode _copyNode(RGANode node) => RGANode(
        id: node.id,
        leftOriginId: node.leftOriginId,
        rightOriginId: node.rightOriginId,
        siteId: node.siteId,
        clock: node.clock,
        value: node.value,
        isDeleted: node.isDeleted,
      );

  /// Update Lamport clock to be at least [receivedClock] + 1.
  void _updateClock(int receivedClock) {
    _clock = _clock > receivedClock ? _clock : receivedClock;
    _clock++;
  }

  /// Rebuild [_indexMap] from scratch.
  void _rebuildIndexMap() {
    _indexMap.clear();
    for (var i = 0; i < _nodes.length; i++) {
      _indexMap[_nodes[i].id] = i;
    }
  }

  /// Find the ID of the left neighbor at the given visible [index].
  String _findLeftNeighborId(int index) {
    if (index <= 0) return _startSentinel;

    var visibleCount = 0;
    for (final node in _nodes) {
      if (!node.isDeleted) {
        visibleCount++;
        if (visibleCount == index) {
          return node.id;
        }
      }
    }

    // Index is at or past the end; use the last visible node.
    for (var i = _nodes.length - 1; i >= 0; i--) {
      if (!_nodes[i].isDeleted) {
        return _nodes[i].id;
      }
    }
    return _startSentinel;
  }

  /// Find the ID of the right neighbor at the given visible [index].
  String _findRightNeighborId(int index) {
    var visibleCount = 0;
    for (final node in _nodes) {
      if (!node.isDeleted) {
        if (visibleCount == index) {
          return node.id;
        }
        visibleCount++;
      }
    }
    return _startSentinel;
  }

  /// Insert a node at the given index and update bookkeeping.
  void _insertAtIndex(int index, RGANode node) {
    _nodes.insert(index, node);
    _nodeMap[node.id] = node;
    _rebuildIndexMap();
  }

  /// Insert a locally-created node into [_nodes] at the correct position.
  void _insertNode(RGANode node) {
    final insertIndex = _computeInsertIndex(node);
    _insertAtIndex(insertIndex, node);
  }

  /// Core RGA algorithm: compute where [node] should be inserted.
  ///
  /// The scan starts right after the anchor (leftOriginId node) and proceeds
  /// rightward up to the rightOrigin boundary. Nodes sharing the same
  /// leftOriginId are ordered by siteId (lexicographic). Nodes with a
  /// different leftOriginId are checked for causal equivalence: if the
  /// current node's leftOrigin chain transitively reaches the new node's
  /// leftOriginId, the siteId tie-breaker is applied.
  int _computeInsertIndex(RGANode node) {
    // Determine the right boundary.
    final int rightBoundaryIndex;
    if (node.rightOriginId.isEmpty) {
      rightBoundaryIndex = _nodes.length;
    } else {
      final idx = _indexMap[node.rightOriginId];
      rightBoundaryIndex = idx ?? _nodes.length;
    }

    // Determine the scan start.
    final int scanStart;
    if (node.leftOriginId.isEmpty) {
      scanStart = 0;
    } else {
      final anchorIndex = _indexMap[node.leftOriginId];
      if (anchorIndex == null) {
        return _nodes.length;
      }
      scanStart = anchorIndex + 1;
    }

    // Cache the anchor ID for the transitive anchor-equivalence check.
    final anchorId = node.leftOriginId;

    var i = scanStart;
    while (i < rightBoundaryIndex && i < _nodes.length) {
      final current = _nodes[i];
      if (_isSameAnchorGroup(current.leftOriginId, anchorId) &&
          current.siteId.compareTo(node.siteId) < 0) {
        i++;
      } else {
        break;
      }
    }
    return i;
  }

  /// Check whether [leftOriginId] is transitively in the same anchor group
  /// as [anchorId].
  ///
  /// A node is in the same anchor group if its leftOriginId equals [anchorId]
  /// or if its leftOriginId refers to a node that is itself in the same
  /// anchor group. The chain is followed up to a reasonable depth.
  bool _isSameAnchorGroup(String leftOriginId, String anchorId) {
    if (leftOriginId == anchorId) return true;
    if (leftOriginId.isEmpty) return anchorId.isEmpty;

    // Follow the leftOrigin chain up to a reasonable depth.
    var currentId = leftOriginId;
    var depth = 0;
    const maxDepth = 64;
    while (currentId.isNotEmpty && currentId != anchorId && depth < maxDepth) {
      final node = _nodeMap[currentId];
      if (node == null) break;
      currentId = node.leftOriginId;
      depth++;
    }
    return currentId == anchorId;
  }
}
