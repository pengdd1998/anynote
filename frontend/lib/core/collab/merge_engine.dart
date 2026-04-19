import 'crdt_text.dart';

/// Encapsulates the result of a merge operation.
class MergeResult {
  /// Number of operations applied from the remote site.
  final int appliedCount;

  /// Whether the local document text changed as a result of the merge.
  final bool hasChanges;

  /// Transformed operations that can be forwarded to other peers.
  final List<RGANode> newOperations;

  const MergeResult({
    required this.appliedCount,
    required this.hasChanges,
    required this.newOperations,
  });

  @override
  String toString() =>
      'MergeResult(applied: $appliedCount, changed: $hasChanges, ops: ${newOperations.length})';
}

/// Manages CRDT text documents and handles inter-peer synchronization.
///
/// Each note is backed by its own [CRDTText] instance, keyed by note ID.
/// The engine provides convenience methods for merging remote operations
/// and extracting operations newer than a given clock value for incremental
/// sync.
class MergeEngine {
  /// Document registry: noteId -> CRDTText.
  final Map<String, CRDTText> _documents = {};

  /// The local site identifier, propagated to every created document.
  final String siteId;

  MergeEngine(this.siteId);

  /// Get or create a CRDT document for the given [noteId].
  CRDTText getDocument(String noteId) {
    return _documents.putIfAbsent(noteId, () => CRDTText(siteId));
  }

  /// Whether the engine currently holds a document for [noteId].
  bool hasDocument(String noteId) => _documents.containsKey(noteId);

  /// Remove a document from the engine (e.g. when a note is deleted).
  void removeDocument(String noteId) {
    _documents.remove(noteId);
  }

  /// Merge remote operations into a local document.
  ///
  /// Returns a [MergeResult] describing what happened:
  /// - [MergeResult.appliedCount]: how many remote ops were processed.
  /// - [MergeResult.hasChanges]: whether the visible text differs after merge.
  /// - [MergeResult.newOperations]: the full operation log post-merge (for
  ///   forwarding to other peers if needed).
  MergeResult mergeRemote(String noteId, List<RGANode> remoteOps) {
    final doc = getDocument(noteId);
    final beforeText = doc.text;
    doc.merge(remoteOps);
    final afterText = doc.text;

    return MergeResult(
      appliedCount: remoteOps.length,
      hasChanges: beforeText != afterText,
      newOperations: doc.getOperations(),
    );
  }

  /// Get all local operations newer than [sinceClock] for a document.
  ///
  /// Useful for incremental sync: the remote peer sends its last-known clock
  /// and receives only the operations it has not yet seen.
  List<RGANode> getOpsSince(String noteId, int sinceClock) {
    final doc = getDocument(noteId);
    return doc.getOpsSince(sinceClock);
  }

  /// Serialize all managed documents for persistence.
  Map<String, dynamic> toJson() {
    return {
      'site_id': siteId,
      'documents': _documents.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  /// Restore engine state from a serialized map.
  factory MergeEngine.fromJson(Map<String, dynamic> json) {
    final engine = MergeEngine(json['site_id'] as String);
    final docs = json['documents'] as Map<String, dynamic>?;
    if (docs != null) {
      for (final entry in docs.entries) {
        engine._documents[entry.key] =
            CRDTText.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    return engine;
  }
}
